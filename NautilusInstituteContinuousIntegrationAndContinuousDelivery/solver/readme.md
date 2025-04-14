# Git Bundle Exploit

The first vulnerability involves hijacking the `main` branch via an insecure `git pull` command.

To create the exploit for this challenge, you need to follow these steps:

- `git add` a malicious actor.x file
- `git add` a payload script (exp.sh)
- `git add` a recursive symlink to itself

Then commit these changes, and branch them to `master` and `evil`

Now want to create the bundle

```bash
git bundle create ../exp.bundle evil main master HEAD
```

We are not done yet! Now we need to corrupt the `evil` branch name in the file with a NULL byte.

Just replace the `e` in `evil` with a null byte

When the server tries to pull `\0vil` from the bundle, it ends up just running `git pull` which will pull in our changes into `main` as well

Now we can fully control main including the `actor.x` file

# Bash Race Exploit

Once we can control the `actor.x` file, we need to exploit the vulnerability in the server to get code execution

The second intended vulnerability is a race condition on the created script files for each of the possible job types.

If we schedule two jobs of the same type but with different inputs, the second to launch will smash the script of the first!

To make this race winnable, we need to conditions:

1 .The second job waits a short bit to allow the first script start executing (if we don't wait, the first job will just run the second jobs script)

2. The first job needs to hang for a bit in the middle of the script, giving the second job time to corrupt the file

To pull of `1.` we can abuse the secret regex filter. We are able to provide a regex which is non-performant, and an input that causes it to be slow.

To pull of `2.` we need to either cause `tar` to take a long time or cause `tar` to crash so that the `|| sleep` command is executed.
We can do this by creating a symlink inside the tarfile which points to itself. This will cause a recursive path explosion which eventually crashes tar


With both of these delays in place, we make sure the second script has a much longer input value.

Then when the first script resumes after the tar, it starts reading at the next location in the bash script (on disk).
However that is now replaced with partial content of the input to the second job, thus allowing us to escape the quotes without any special characters.

