// ANSI color codes
const RESET = "\x1b[0m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const BLUE = "\x1b[34m";
const MAGENTA = "\x1b[35m";
const CYAN = "\x1b[36m";
const WHITE = "\x1b[37m";
const BRIGHT = "\x1b[1m";
const DIM = "\x1b[2m";

// ASCII Art
const ATM_ART = `
${CYAN}╔══════════════════════════════════════════════════════╗
║ ${BRIGHT}╔═╗╔╦╗╔╦╗  ╔╦╗╔═╗╔═╗╦ ╦╦╔╗╔╔═╗  ╔╦╗╔═╗╔═╗╦ ╦╦╔╗╔╔═╗${RESET}${CYAN}  ║
║ ${BRIGHT}╠═╣ ║ ║║║──║║║╠═╣║  ╠═╣║║║║║╣ ──║║║╠═╣║  ╠═╣║║║║║╣ ${RESET}${CYAN}  ║
║ ${BRIGHT}╩ ╩ ╩ ╩ ╩  ╩ ╩╩ ╩╚═╝╩ ╩╩╝╚╝╚═╝  ╩ ╩╩ ╩╚═╝╩ ╩╩╝╚╝╚═╝${RESET}${CYAN}  ║
║                                                      ║
║  ${MAGENTA}┌─────────────────────┐${CYAN}                             ║
║  ${MAGENTA}│     ${WHITE}MEMORY BANK${MAGENTA}     │${CYAN}                             ║
║  ${MAGENTA}└─────────────────────┘${CYAN}                             ║
║                                                      ║
║  ${YELLOW}┌─────┬─────┬─────┐${CYAN}                                 ║
║  ${YELLOW}│  ${WHITE}1${YELLOW}  │  ${WHITE}2${YELLOW}  │  ${WHITE}3${YELLOW}  │${CYAN}                                 ║
║  ${YELLOW}├─────┼─────┼─────┤${CYAN}                                 ║
║  ${YELLOW}│  ${WHITE}4${YELLOW}  │  ${WHITE}5${YELLOW}  │  ${WHITE}6${YELLOW}  │${CYAN}                                 ║
║  ${YELLOW}├─────┼─────┼─────┤${CYAN}                                 ║
║  ${YELLOW}│  ${WHITE}7${YELLOW}  │  ${WHITE}8${YELLOW}  │  ${WHITE}9${YELLOW}  │${CYAN}                                 ║
║  ${YELLOW}├─────┼─────┼─────┤${CYAN}                                 ║
║  ${YELLOW}│  ${WHITE}*${YELLOW}  │  ${WHITE}0${YELLOW}  │  ${WHITE}#${YELLOW}  │${CYAN}                                 ║
║  ${YELLOW}└─────┴─────┴─────┘${CYAN}                                 ║
║                                                      ║
║  ${GREEN}╔══════════════════╗${CYAN}                                ║
║  ${GREEN}║ ${WHITE}INSERT CARD HERE${GREEN} ║${CYAN}                                ║
║  ${GREEN}╚══════════════════╝${CYAN}                                ║
║                                                      ║
║  ${BLUE}┌─────────────────┐${CYAN}                                 ║
║  ${BLUE}│ ${WHITE}CASH DISPENSER${BLUE}  │${CYAN}                                 ║
║  ${BLUE}└─────────────────┘${CYAN}                                 ║
╚══════════════════════════════════════════════════════╝${RESET}`;

const MARBLE_TOP = `
${DIM}${WHITE}╔══════════════════════════════════════════════════════╗
║ ▓▓░░▓▓░░▓▓░░▓▓░░▓▓░░▓▓░░▓▓░░▓▓░░▓▓░░▓▓░░▓▓░░▓▓░░▓▓   ║
║ ░░▓▓░░▓▓░░▓▓░░▓▓░░▓▓░░▓▓░░▓▓░░▓▓░░▓▓░░▓▓░░▓▓░░▓▓░░   ║
║ ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒   ║
╚══════════════════════════════════════════════════════╝${RESET}`;

const MARBLE_BOTTOM = `
${DIM}${WHITE}╔══════════════════════════════════════════════════════╗
║ ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒   ║
║ ░░▓▓░░▓▓░░▓▓░░▓▓░░▓▓░░▓▓░░▓▓░░▓▓░░▓▓░░▓▓░░▓▓░░▓▓░░   ║
║ ▓▓░░▓▓░░▓▓░░▓▓░░▓▓░░▓▓░░▓▓░░▓▓░░▓▓░░▓▓░░▓▓░░▓▓░░▓▓   ║
╚══════════════════════════════════════════════════════╝${RESET}`;

class User {
  constructor(username) {
    this.username = username;
    this.balance = 101;
    this.signature = null;
  }
}

class Bill {
  constructor(value, signature) {
    this.value = value;
    this.serialNumber = 'SN-' + crypto.randomUUID();
    this.signature = new Uint8Array(signature.length);
    for (let i = 0; i < signature.length; i++) {
      this.signature[i] = signature.charCodeAt(i);
    }
  }
  
  toString() {
    return `${this.value} token bill (S/N: ${this.serialNumber})`;
  }
}

class UserRegistry {
  constructor() {
    this.users = [];
  }
  addUser(user) {
    this.users.push(new WeakRef(user));
  }
  getUserByUsername(username) {
    for (let user of this.users) {
      user = user.deref();
      if (!user) continue;
      if (user.username === username) {
        return user;
      }
    }
    return null;
  }
  
  *[Symbol.iterator]() {
    for (const weakRef of this.users) {
      const user = weakRef.deref();
      if (user) yield user;
    }
  }
}
const users = new UserRegistry();

function promptSync(message) {
  const buf = new Uint8Array(1024*1024);
  Deno.stdout.writeSync(new TextEncoder().encode(`${YELLOW}${message}${RESET}`));
  const n = Deno.stdin.readSync(buf);
  return new TextDecoder().decode(buf.subarray(0, n)).trim();
}

function init() {
  users.addUser(new User("bank_manager"));
}

async function main() {
  init();
  console.log(ATM_ART);
  console.log(MARBLE_TOP);
  console.log(`${BRIGHT}${CYAN}Welcome to the Memory Banking System! Loading...${RESET}`);
  console.log(MARBLE_BOTTOM);

  setTimeout(async () => {
    await user();
  }, 1000);
}

async function user() {
  
  let isLoggedIn = false;
  let currentUser = null;
  
  while (true) {
    // If not logged in, require registration
    if (!isLoggedIn) {
      console.log(`${YELLOW}You have 20 seconds to complete your transaction before the bank closes for the day.\n${RESET}`);
      
      // Register user
      while (!isLoggedIn) {
        let username = promptSync("Please register with a username (or type 'exit' to quit): ");
        if (!username) {
          console.log(`${CYAN}Thank you for using Memory Banking System!${RESET}`);
          Deno.exit(0);
        }
        
        if (username.toLowerCase() === 'exit') {
          console.log(`${CYAN}Thank you for using Memory Banking System!${RESET}`);
          Deno.exit(0);
        }

        if (username.toLowerCase() === 'random') {
          username = 'random-' + crypto.randomUUID();
        } else {
          let existingUser = users.getUserByUsername(username);
      
          if (existingUser) {
            console.log(`${MAGENTA}User already exists. Please choose another username.${RESET}`);
            continue;
          }
        }

        currentUser = new User(username);
        users.addUser(currentUser);
        if (currentUser.username === "bank_manager") {
          currentUser.balance = 100000000;
        }
        console.log(MARBLE_TOP);
        console.log(`${BRIGHT}${GREEN}Welcome, ${username}! Your starting balance is ${currentUser.balance} tokens.${RESET}`);
        console.log(MARBLE_BOTTOM);
        
        isLoggedIn = true;
      }
    }
  
    // Banking operations
    console.log("\n" + MARBLE_TOP);
    console.log(`${CYAN}${BRIGHT}Available operations:${RESET}`);
    console.log(`${CYAN}1. Check balance${RESET}`);
    console.log(`${CYAN}2. Withdraw tokens${RESET}`);
    console.log(`${CYAN}3. Set signature${RESET}`);
    console.log(`${CYAN}4. Logout${RESET}`);
    console.log(`${CYAN}5. Exit${RESET}`);
    
    // Special admin option for bank_manager
    if (currentUser.username === "bank_manager") {
      console.log(`${MAGENTA}${BRIGHT}6. Vault: Withdrawflag${RESET}`);
    }
    console.log(MARBLE_BOTTOM);
    
    const choice = promptSync("Choose an operation (1-" + (currentUser.username === "bank_manager" ? "6" : "5") + "): ");
    
    switch (choice) {
      case "1":
        console.log(`${GREEN}Your balance is ${BRIGHT}${currentUser.balance}${RESET}${GREEN} tokens.${RESET}`);
        break;
        
      case "2":
        const amount = parseInt(promptSync("Enter amount to withdraw: "));
        
        if (isNaN(amount) || amount <= 0) {
          console.log(`${MAGENTA}Invalid amount.${RESET}`);
          continue;
        }
        
        if (amount > currentUser.balance) {
          console.log(`${MAGENTA}Insufficient funds.${RESET}`);
          continue;
        }
        
        const billOptions = [1, 5, 10, 20, 50, 100];
        console.log(`${YELLOW}Available bill denominations: ${billOptions.join(", ")}${RESET}`);
        const denomStr = promptSync("Enter bill denomination: ");
        const denomination = parseFloat(denomStr);

        if (denomination <=0 || isNaN(denomination) || denomination > amount) {
          console.log(`${MAGENTA}Invalid denomination: ${denomination}${RESET}`);
          continue;
        }

        const numBills = amount / denomination;
        const bills = [];

        for (let i = 0; i < numBills; i++) {
          bills.push(new Bill(denomination, currentUser.signature || 'VOID'));
        }
        
        currentUser.balance -= amount;
        
        console.log(`${GREEN}Withdrew ${BRIGHT}${amount}${RESET}${GREEN} tokens as ${bills.length} bills of ${denomination}:${RESET}`);
        //bills.forEach(bill => console.log(`- ${bill}`));
        console.log(`${GREEN}Remaining balance: ${BRIGHT}${currentUser.balance}${RESET}${GREEN} tokens${RESET}`);
        break;
        
      case "3":
        // Set signature
        const signature = promptSync("Enter your signature (will be used on bills): ");
        currentUser.signature = signature;
        console.log(`${GREEN}Your signature has been updated${RESET}`);
        break;
        
      case "4":
        // Logout
        console.log(`${YELLOW}You have been logged out.${RESET}`);
        isLoggedIn = false;
        currentUser = null;
        break;
        
      case "5":
        // Exit
        console.log(MARBLE_TOP);
        console.log(`${CYAN}${BRIGHT}Thank you for using Memory Banking System!${RESET}`);
        console.log(MARBLE_BOTTOM);
        Deno.exit(0);
        
      case "6":
        if (currentUser.username === "bank_manager") {
          try {
            const flag = Deno.readTextFileSync("/flag");
            console.log(`${BRIGHT}${GREEN}Flag contents:${RESET}`);
            console.log(`${BRIGHT}${GREEN}${flag}${RESET}`);
          } catch (err) {
            console.log(`${MAGENTA}Error reading flag file:${RESET}`, err.message);
          }
        } else {
          console.log(`${MAGENTA}${BRIGHT}Unauthorized access attempt logged 🚨🚨🚨🚨🚨🚨${RESET}`);
        }
        break;
                    
      default:
        console.log(`${MAGENTA}Invalid option.${RESET}`);
    }
  }
}

main().catch(err => {
  console.error(`${MAGENTA}An error occurred:${RESET}`, err);
  Deno.exit(1);
});