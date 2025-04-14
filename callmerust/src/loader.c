
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/ptrace.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/user.h>
#include <signal.h>
#include <errno.h>
#include <string.h>
#include <linux/prctl.h>
#include <sys/prctl.h>
#include <errno.h>
#include <stdio.h>
#include <sys/wait.h>
#include <signal.h>
#include <sys/ptrace.h>
#include <errno.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/resource.h>

//#define DEBUGP


unsigned char FLAG[200];
int gchild = 0;
FILE* gfd;



unsigned long find_flag_in_main_binary(pid_t pid){
    // We'll store the start/end of the main binary's mapped segment
    unsigned long start_addr = 0, end_addr = 0;
    char path[64], line[512];
    snprintf(path, sizeof(path), "/proc/%d/maps", pid);

    // 1) Open /proc/PID/maps
    FILE *maps_file = fopen(path, "r");
    if (!maps_file){return 0;}

    char* tline;

    tline = fgets(line, sizeof(line)-1, maps_file);
    if(tline==NULL){ return 0;}
    tline = fgets(line, sizeof(line)-1, maps_file);
    if(tline==NULL){ return 0;}
    tline = fgets(line, sizeof(line)-1, maps_file);
    if(tline==NULL){ return 0;}
    int res;
    res = sscanf(line, "%lx-%lx", &start_addr, &end_addr);
    if(res!=2){
        _exit(51);
    }
#ifdef DEBUG
    fprintf(gfd, "---> %lx %lx\n", start_addr, end_addr); fflush(gfd);
#endif
    fclose(maps_file);
    if (start_addr == 0 || end_addr == 0){ return 0;}

    // 2) Open /proc/PID/mem
    snprintf(path, sizeof(path), "/proc/%d/mem", pid);
    int mem_fd = open(path, O_RDONLY);
    if (mem_fd < 0){ return 0;}
    size_t region_size = (size_t)(end_addr - start_addr);
    if(region_size<0x1000 || region_size>0x20000){
        _exit(52);
    }
    char *buf = malloc(region_size);
    if (!buf) {
        close(mem_fd);
        return 0;
    }
    if (lseek(mem_fd, (off_t)start_addr, SEEK_SET) == (off_t)-1) {
        free(buf);
        close(mem_fd);
        return 0;
    }
    ssize_t bytes_read = read(mem_fd, buf, region_size);
    close(mem_fd);
    if (bytes_read <= 0) {
        free(buf);
        return 0;
    }

    // 3) Search for "flag" in the buffer
    const char *needle = "flag";
    size_t needle_len = strlen(needle);
    unsigned long result_addr = 0;
    int found = 0;
    // A simple naive search
    for (ssize_t i = 0; i <= bytes_read - (ssize_t)needle_len; i++) {
#ifdef DEBUGP
        //fprintf(gfd, "---> %lx\n", result_addr); fflush(gfd);
#endif
        if (memcmp(buf + i, needle, needle_len) == 0) {
            found += 1;
            result_addr = start_addr + i;
        }
    }
    if(found!=1){
        result_addr = 0;
    }

    free(buf);
    return result_addr;
}



static void print_process_cmdline(FILE *fd, pid_t pid){
    char path[64];
    snprintf(path, sizeof(path), "/proc/%d/cmdline", pid);

    FILE *f = fopen(path, "rb");
    if (!f) {
#ifdef DEBUGP
        fprintf(fd, "    * Could not open %s: %s\n", path, strerror(errno));
#endif
        return;
    }

    // The cmdline file is a series of '\0'-separated strings (argv[0]..argv[n]).
    char buf[4096];
    size_t n = fread(buf, 1, sizeof(buf) - 1, f);
    fclose(f);

    if (n == 0) {
#ifdef DEBUGP
        fprintf(fd, "    * cmdline: (empty or unreadable)\n");
#endif
        return;
    }
    buf[n] = '\0';

    // Replace embedded '\0' with spaces so it's readable as one line
    for (size_t i = 0; i < n; i++) {
        if (buf[i] == '\0') {
            buf[i] = ' ';
        }
    }

#ifdef DEBUGP
    fprintf(fd, "    * cmdline: %s\n", buf);
#endif
}


void parse_wait_status(FILE *fd, pid_t child_pid, int status){
#ifdef DEBUGP
    // Print raw status
    fprintf(fd, "ChildPID=%d status=0x%08X(%d)\n", child_pid, status, status);

    // 1) Normal exit?
    if (WIFEXITED(status)) {
        fprintf(fd, "  - WIFEXITED: true\n");
        fprintf(fd, "    * Exit code: %d\n", WEXITSTATUS(status));
        print_process_cmdline(fd, child_pid);
    } else {
        fprintf(fd, "  - WIFEXITED: false\n");
    }

    // 2) Killed by a signal?
    if (WIFSIGNALED(status)) {
        int sig = WTERMSIG(status);
        fprintf(fd, "  - WIFSIGNALED: true\n");
        fprintf(fd, "    * Terminating signal: %d (%s)\n", sig, strsignal(sig));
        if (WCOREDUMP(status)) {
            fprintf(fd, "    * Core dumped: yes\n");
        } else {
            fprintf(fd, "    * Core dumped: no\n");
        }
        print_process_cmdline(fd, child_pid);
    } else {
        fprintf(fd, "  - WIFSIGNALED: false\n");
    }

    // 3) Stopped?
    if (WIFSTOPPED(status)) {
        int sig = WSTOPSIG(status);
        fprintf(fd, "  - WIFSTOPPED: true\n");
        fprintf(fd, "    * Stopping signal: %d (%s)\n", sig, strsignal(sig));

        // If SIGTRAP, maybe there's a ptrace event in the high 16 bits:
        if (sig == SIGTRAP) {
            unsigned ptrace_event = (unsigned)((status >> 16) & 0xffff);
            if (ptrace_event != 0) {
                // It's one of the PTRACE_EVENT_* codes
                fprintf(fd, "    * ptrace event code: %u\n", ptrace_event);

                // We can get more details with PTRACE_GETEVENTMSG
                unsigned long eventmsg = 0;
                if (ptrace(PTRACE_GETEVENTMSG, child_pid, NULL, &eventmsg) == 0) {
                    // eventmsg typically holds the new child's PID on FORK, VFORK, CLONE,
                    // or zero on EXEC, etc.
                    fprintf(fd, "    * PTRACE_GETEVENTMSG = %lu\n", eventmsg);
                } else {
                    fprintf(fd, "    * PTRACE_GETEVENTMSG failed: %s\n", strerror(errno));
                }

                // Optionally interpret the event code:
                switch (ptrace_event) {
                case PTRACE_EVENT_FORK:
                    fprintf(fd, "    -> PTRACE_EVENT_FORK\n");
                    break;
                case PTRACE_EVENT_VFORK:
                    fprintf(fd, "    -> PTRACE_EVENT_VFORK\n");
                    break;
                case PTRACE_EVENT_CLONE:
                    fprintf(fd, "    -> PTRACE_EVENT_CLONE\n");
                    break;
                case PTRACE_EVENT_EXEC:
                    fprintf(fd, "    -> PTRACE_EVENT_EXEC\n");
                    print_process_cmdline(fd, child_pid);
                    break;
                case PTRACE_EVENT_VFORK_DONE:
                    fprintf(fd, "    -> PTRACE_EVENT_VFORK_DONE\n");
                    break;
                case PTRACE_EVENT_EXIT:
                    fprintf(fd, "    -> PTRACE_EVENT_EXIT\n");
                    print_process_cmdline(fd, child_pid);
                    break;
                default:
                    fprintf(fd, "    -> Unknown ptrace event\n");
                    break;
                }
            }
        }

    } else {
        fprintf(fd, "  - WIFSTOPPED: false\n");
    }

    // 4) Continued (after a stop)?
    if (WIFCONTINUED(status)) {
        fprintf(fd, "  - WIFCONTINUED: true\n");
    } else {
        fprintf(fd, "  - WIFCONTINUED: false\n");
    }

    //fprintf(fd, "FC=%d EC=%d\n", FC, EC);  // blank line for readability
    fflush(fd);
#endif
}


size_t read_five_newlines_or_10k(unsigned char *buffer){
    size_t total = 0;                // number of bytes stored in 'buffer'
    int consecutive_newlines = 0;    // how many newlines in a row so far

    while (total < 10000 - 1) {
        char chunk[1024];
        ssize_t n = read(STDIN_FILENO, chunk, sizeof(chunk));

        if (n < 0) {
            _exit(1);
            break;
        }
        if (n == 0) {
            _exit(1);
            break;
        }

        // Process each byte in this chunk
        for (ssize_t i = 0; i < n; i++) {
            if (chunk[i] == '\n') {
                consecutive_newlines++;
            } else {
                consecutive_newlines = 0;
            }

            buffer[total++] = chunk[i];

            // If we have 5 consecutive newlines, or we're out of space, stop
            if (consecutive_newlines == 5 || total == 10000 - 1) {
                break;
            }
        }

        // If we stopped due to 5 newlines or buffer is full, break the outer loop
        if (consecutive_newlines == 5 || total == 10000 - 1) {
            break;
        }
    }

    return total;
}


void read_flag(const char *filename, size_t max_size){
    FILE *fp = fopen(filename, "rb");
    if (!fp) {
        _exit(2);
    }

    size_t bytes_read = fread(FLAG, 1, max_size, fp);
    if(bytes_read < 1){
        _exit(2);
    }
    FLAG[bytes_read] = '\x00';
    int res = fclose(fp);
    if(res!=0){
        _exit(2);
    }
}


void kill_all_and_exit(FILE *fd, int child_pid, int status){
    unsigned long other_child = 0;
    int res = 0;
    int wres = 0;

    ptrace(PTRACE_GETEVENTMSG, child_pid, NULL, &other_child);
#ifdef DEBUGF
    fprintf(fd, "Killing all! %ld %d %d\n", other_child, child_pid, getpid()); fflush(fd);
#endif

    if(other_child != 0){
        res = kill(other_child, 9);
        if(res!=0){
#ifdef DEBUGF
            fprintf(fd, "kill2 error %d %d\n", res, errno); fflush(fd);
#endif
        }
        while(1){
            wres = waitpid(other_child, NULL, 0);
#ifdef DEBUGF
            fprintf(fd, "- killing2 %ld %d\n", other_child, wres); fflush(fd);
#endif
            if(wres == -1){ break;}
        }
    }
    res = kill(child_pid,9);
    if(res!=0){
#ifdef DEBUGF
        fprintf(fd, "kill1 error %d %d\n", res, errno); fflush(fd);
#endif
    }
    while(1){
        wres = waitpid(child_pid, NULL, 0);
#ifdef DEBUGF
        fprintf(fd, "- killing1 %d %d\n", child_pid, wres); fflush(fd);
#endif
        if(wres == -1){ break;}
    }
    _exit(11);
}


void on_alarm(int signum){
    if (signum == SIGALRM) {
#ifdef DEBUGF
        fprintf(gfd, "got sigalarm %d\n", gchild); fflush(gfd);
#endif
        if(gchild != 0){
            kill(gchild, 9);
#ifdef DEBUGF
            fprintf(gfd, "got sigalarm %d killed\n", gchild); fflush(gfd);
#endif
        }
    }
}


int main(int argc, char** argv, char** env){
    pid_t child;
    int status;
    int res=0;

    setvbuf(stdout, NULL, _IONBF, 0);
    setvbuf(stderr, NULL, _IONBF, 0);
    setvbuf(stdin, NULL, _IONBF, 0);

    const char *tfilepath = "/opt/privuserdir/f";
    if (faccessat(AT_FDCWD, tfilepath, F_OK, AT_EACCESS) != 0) {
        _exit(30);
    }
    if (remove(tfilepath) != 0) {
        _exit(31);
    }

    read_flag("/home/privuser/flag", sizeof(FLAG)-1);

    uid_t ruid = getuid();
    gid_t rgid = getgid();
    if (setresgid(rgid, rgid, rgid) < 0) {
        _exit(21);
    }
    if (setresuid(ruid, ruid, ruid) < 0) {
        _exit(21);
    }

    res = chdir("workdir");
    if(res!=0) { _exit(22); }

    unsigned char buffer[20000];
    for(int i=0; i<sizeof(buffer); i++){
        buffer[i]='\x00';
    }
    printf("Hello! Send me your code (terminated by 5 new lines)\n");
    res = read_five_newlines_or_10k(buffer);
    if(res<=0) { _exit(1); }
    int readlen = res;
    //printf("%d!\n", readlen);

    FILE* fp1 = fopen("src/main.rs", "wb");
    if(fp1==NULL){ _exit(5); }
    char header1[] = "\n#![forbid(unsafe_code)]\n\n#[macro_export]\nmacro_rules! panic {\n() => {\ncompile_error!(\"`panic!` is forbidden by this crate\");\n};\n($($t:tt)*) => {\ncompile_error!(\"`panic!(...)` is forbidden by this crate\");\n};\n}\n\n\n";
    res = fwrite(header1, 1, sizeof(header1)-1, fp1);
    if(res<=0){ _exit(5); }
    res = fwrite(buffer, 1, readlen, fp1);
    if(res<=0){ _exit(5); }
    fclose(fp1);

    //res = system("/usr/bin/timeout -k 1 5 /usr/bin/cargo build --release");//  > /dev/null 2>&1");
    res = system("/usr/bin/timeout -k 1 5 /usr/bin/cargo build --release > /dev/null 2>&1");
    if(res!=0){
        printf("Compilation error!\n");
        _exit(6);
    }

    child = fork();
    if (child < 0) {
        _exit(7);
    }

    if (child == 0) {
        prctl(1, 9);
        prctl(PR_SET_DUMPABLE,1);

        struct rlimit limit;
        limit.rlim_cur = 20;
        limit.rlim_max = 20;
        if (setrlimit(RLIMIT_CPU, &limit) != 0) {
            _exit(17);
        }
        limit.rlim_cur = 1 * 1024 * 1024;
        limit.rlim_max = 1 * 1024 * 1024;
        if (setrlimit(RLIMIT_FSIZE, &limit) != 0) {
            _exit(17);
        }
        limit.rlim_cur = 128 * 1024*1024;
        limit.rlim_max = 128 * 1024*1024;
        if (setrlimit(RLIMIT_AS, &limit) != 0) {
            _exit(17);
        }

        raise(SIGSTOP);
        printf("Running the code...\n");

        char *argv[] = {"/opt/workdir/target/release/libmerust", NULL}; execve(argv[0], argv, env);
        //char *argv[] = {"./ftester", "123", NULL}; execve("./ftester", argv, env);
        //char *argv[] = {"/bin/bash", NULL};
        //execve("/bin/bash", argv, env);
        //char *argv[] = {"/usr/bin/python3", "./execveat.py", NULL};
        //execve("/usr/bin/python3", argv, env);

        _exit(4);

    } else {
        close(0);
        close(1);
        close(2);

#ifdef DEBUGP
        FILE* fd = fopen("log.txt", "wb");
        fprintf(fd, "=====\nout1 %d\n", child); fflush(fd);
#else
        FILE* fd = NULL;
#endif

        /*char selfpath[255];
        ssize_t len = readlink("/proc/self/exe", selfpath, sizeof(selfpath) - 1);
        if (len == -1) {
            kill_all_and_exit(fd, child, status);
        }
        selfpath[len] = '\0';
        if (unlink(selfpath) == -1) {
            kill_all_and_exit(fd, child, status);
        }*/
        res = prctl(PR_SET_DUMPABLE, 0); //SUID_DUMP_DISABLE
        if(res<0){
            kill_all_and_exit(fd, child, status);
        }
        res = prctl(PR_SET_PTRACER, 0);
        if(res<0){
            kill_all_and_exit(fd, child, status);
        }

        usleep(100);

#ifdef DEBUGF
        fprintf(fd, "out3\n"); fflush(fd);
#endif

        int state = 0;
        res = ptrace(PTRACE_ATTACH, child, NULL, NULL);
        if(res!=0){
#ifdef DEBUGF
            fprintf(fd, "attach error %d %d\n", res, errno); fflush(fd);
#endif
            kill_all_and_exit(fd, child, status);
        }

        while (1) {
            pid_t cpid = waitpid(-1, &status, 0);
            if(cpid == -1){
#ifdef DEBUGF
                fprintf(fd,"waitpid failed\n"); fflush(fd);
#endif
                break;
            }
#ifdef DEBUGF
            fprintf(fd, "STATE: %d\n", state); fflush(fd);
#endif
            parse_wait_status(fd, cpid, status);

            if(state==0){
                long options = PTRACE_O_TRACEFORK | PTRACE_O_TRACEVFORK | PTRACE_O_TRACECLONE | PTRACE_O_TRACEEXEC | PTRACE_O_EXITKILL;
                res = ptrace(PTRACE_SETOPTIONS, cpid, NULL, options);
                if(res!=0){
#ifdef DEBUGF
                    fprintf(fd, "setoptions error %d\n", res); fflush(fd);
#endif
                    kill_all_and_exit(fd, child, status);
                }
                gchild = cpid;
                gfd = fd;
                signal(SIGALRM, on_alarm);
                alarm(30);
                state = 1;
#ifdef DEBUGF
                fprintf(fd, "===> setoptions setup and alarm set\n"); fflush(fd);
#endif
            }


            if (WIFSTOPPED(status)) {
                int sig = WSTOPSIG(status);
                if (sig == SIGTRAP) {
                    unsigned ptrace_event = (unsigned)((status >> 16) & 0xffff);
                    if (ptrace_event != 0) {
                        switch (ptrace_event) {
                            case PTRACE_EVENT_FORK:
                            case PTRACE_EVENT_VFORK:
                            case PTRACE_EVENT_CLONE:
                            case PTRACE_EVENT_EXEC:
                                if(state == 1){
                                    state = 2;
#ifdef DEBUGF
                                    fprintf(fd, "= STATE IS 2\n"); fflush(fd);
#endif
                                }else{
                                    kill_all_and_exit(fd, cpid, status);
                                }
                        }
                    }else{
                        struct user_regs_struct regs;
                        unsigned long data;
                        int rest;
#ifdef DEBUGF
                        fprintf(fd, "= BREAKPOINT HIT\n"); fflush(fd);
#endif

                        res = ptrace(PTRACE_GETREGS, child, NULL, &regs);
                        if(res==-1){
                            kill_all_and_exit(fd, cpid, status);
                        }
                        data = ptrace(PTRACE_PEEKDATA, child, (void*)(regs.rip-8), NULL);
#ifdef DEBUGF
                        fprintf(fd, "--------> %lx\n", data); fflush(fd);
#endif
                        if(data!=0xcc0000000000841f){
                            kill_all_and_exit(fd, cpid, status);
                        }
                        data = ptrace(PTRACE_PEEKDATA, child, (void*)(regs.rip-8-1), NULL);
#ifdef DEBUGF
                        fprintf(fd, "--------> %lx\n", data); fflush(fd);
#endif
                        if(data!=0x0000000000841f0f){
                            kill_all_and_exit(fd, cpid, status);
                        }

                        unsigned long caddr = find_flag_in_main_binary(cpid);
#ifdef DEBUGF
                        fprintf(fd, "--------> %lx\n", caddr); fflush(fd);
#endif
                        if(caddr == 0){
                            kill_all_and_exit(fd, cpid, status);
                        }
                        char path[64];
                        snprintf(path, sizeof(path), "/proc/%d/mem", cpid);
                        int mem_fd = open(path, O_WRONLY);
                        if (mem_fd < 0){ return 0;}
                        if (lseek(mem_fd, (off_t)caddr, SEEK_SET) == (off_t)-1) {
                            close(mem_fd);
                            kill_all_and_exit(fd, cpid, status);
                        }
                        rest = write(mem_fd, FLAG, strlen(FLAG));
                        if(rest<=0){
                            kill_all_and_exit(fd, cpid, status);
                        }
#ifdef DEBUGF
                        //fprintf(fd, "***> %s %d\n", FLAG, strlen(FLAG)); fflush(fd);
#endif
                        close(mem_fd);

                    }
                }else if(sig == SIGSEGV){
                    kill(cpid, 9);
                }
            }

            usleep(1);
            ptrace(PTRACE_CONT, cpid, NULL, NULL);
        }
    }

    return 0;
}



