
use rand::{Rng, seq::SliceRandom, distributions::Uniform};
use std::{process, fmt::Debug};
use std::panic::{AssertUnwindSafe, catch_unwind};
use std::arch::asm;
static mut V: bool = false;
static mut M: u128 = 0;
static mut S: bool = false;
static FLAG: [u8; 160+1] = [b'f', b'l', b'a', b'g', b'{', b'F', b'A', b'K', b'E', b'F', b'L', b'A', b'G', b'F', b'A', b'K', b'E', b'F', b'L', b'A', b'G', b'F', b'A', b'K', b'E', b'F', b'L', b'A', b'G', b'-', b'F', b'A', b'K', b'E', b'F', b'L', b'A', b'G', b'F', b'A', b'K', b'E', b'F', b'L', b'A', b'G', b'F', b'A', b'K', b'E', b'F', b'L', b'A', b'G', b'-', b'F', b'A', b'K', b'E', b'F', b'L', b'A', b'G', b'F', b'A', b'K', b'E', b'F', b'L', b'A', b'G', b'F', b'A', b'K', b'E', b'F', b'L', b'A', b'G', b'-', b'F', b'A', b'K', b'E', b'F', b'L', b'A', b'G', b'F', b'A', b'K', b'E', b'F', b'L', b'A', b'G', b'F', b'A', b'K', b'E', b'F', b'L', b'A', b'G', b'-', b'F', b'A', b'K', b'E', b'F', b'L', b'A', b'G', b'F', b'A', b'K', b'E', b'F', b'L', b'A', b'G', b'F', b'A', b'K', b'E', b'F', b'L', b'A', b'G', b'F', b'A', b'K', b'E', b'F', b'L', b'A', b'G', b'F', b'A', b'K', b'E', b'F', b'L', b'A', b'G', b'F', b'A', b'K', b'E', b'F', b'L', b'A', b'G', b'f', b'a', b'k', b'e', b'-', b'-', b'}', 0];
#[inline(always)]
fn rr(mut s: u32) -> u32 {
    const A: u64 = 1664525;
    const C: u64 = 1013904223;
    const M1: u128 = 1_u128 << 32;
    const M2: u64 = 281474976710665;
    fn mm(mut e: u64, mut b: u64, m: u64) -> u64 {
        let mut r: u64 = 1;
        e %= m;
        while b > 0 {
            if (b & 1) == 1 {
                let tmp = (r as u128) * (e as u128) % (m as u128);
                r = tmp as u64;
            }
            let tmp = (e as u128) * (e as u128) % (m as u128);
            e = tmp as u64;
            b >>= 1;
        }
        r
    }
    let mut rrr : u64;
    let s2 = s as u64;
    rrr = 1;
    for m in s2..(s2+5000){
        let mut x = m;
        for _ in 0..6000{
            x = match x % 4 {
                0 | 2 => x / 2,
                1 => x * 7 + 1,
                3 => x * 7 - 1,
                _ => unreachable!(),
            }
        }
        rrr = rrr*(x/9+1);
    }
    let i = (s as u64 % 3) + 7;
    for _ in 0..i {
        let p = rrr * mm(s as u64, 65537, M2);
        let tmp = (A as u128) * (p as u128) + (C as u128);
        s = (tmp % M1) as u32;
    }
    s
}
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
#[inline(always)]
fn bb() -> Vec<u128> {
    let mut g = rand::thread_rng();
    let br = Uniform::new(100_000, 99_999_999_999_999);
    let mut u: Vec<u128> = (0..200).map(|_| g.sample(br)).collect();
    u.shuffle(&mut g);
    let mut c = u.iter().filter(|&&n| p(n)).count();
    while c < 15 {
        let index = g.gen_range(0..200);
        let pp = loop {
            let cc = g.sample(br);
            if p(cc) {
                break cc;
            }
        };
        u[index] = pp;
        u.shuffle(&mut g);
        c = u.iter().filter(|&&n| p(n)).count();
    }
    u
}
#[inline(always)]
fn dd(n: u128) -> u128 {
    let ds: Vec<u128> = n.to_string().chars().map(|c| c.to_digit(10).unwrap() as u128) .collect();
    let mut r: u128 = 1;
    for (i, &d) in ds.iter().enumerate() {
        let x = ds.get(i + 1).copied().unwrap_or(1);
        let w = d.wrapping_pow(x as u32);
        r = r.wrapping_mul(w);
    }
    r
}
macro_rules! ಠ_ಠ {
    ($x:expr, $y:expr) => {{
        [(), ()].iter().any(|_| {
            let ref w = $x;
            let ref t = $y;
            match w == t {
                true => return true,
                _ => return false,
            }
        })
    }};
}
#[inline(always)]
fn x(x: u128, y: u128) -> bool {
    ಠ_ಠ!(x, y)
}
pub fn zzz<F1, F2, F3>(f1: F1, f2: F2, f3: F3, data: &[(u32, u32); 16])
where
    F1: FnOnce(Vec<u128>, F2) -> u128,
    F2: FnOnce(u128, F3) -> u128 + Clone + Debug,
    F3: Fn(u128) -> u128,
{
    let array = bb();
    if data.len() !=16{
        return;
    }
    let brr: u128 = array.iter().filter(|&&n| p(n)).map(|&n| dd(n)).fold(0, |acc, x| acc.wrapping_add(x));
    let exec = catch_unwind(AssertUnwindSafe(|| {
        if f1(array.clone(), f2) != brr { process::exit(0); }
        else{
            let mut pp1 = false;
            let mut pp2 = false;
            let mut pp3 = false;
            for e in &array{
                if f3(*e) % 6553 == 0{
                    pp1 = !pp1;
                }
                else if pp1{
                    if f3(*e) == 9_999_991{
                        pp2 = !pp2;
                    }
                }
                else if pp2{
                    if x(rr(3558915696_u128.wrapping_mul(f3(*e)) as _) as _, 3905797006_u128){
                        pp3 = !pp3;
                    }
                }
                else if pp3{
                    if f3(*e) % 999331 == 0{
                        unsafe {
                            V = !V;
                            M = brr;
                        }
                    }
                }
            }
            if unsafe{V}{
                if unsafe{S}{
                    if x(rr(f3(!array[15] - brr) as _) as _, 1000000575_u128){
                        panic!("{}", rr(f3(!array[15] + brr) as _));
                    }
                }
                else{
                    unsafe{
                        V = false;
                        S = false;
                    }
                }
            }
            else{
                unsafe{
                    S = !S;
                };
            }
        }
    }));
    match exec {
        Ok(_) => {},
        Err(e) => {
            if let Some(cc) = e.downcast_ref::<u128>() {
                if unsafe{V && S}{
                    if *cc == unsafe{M}{
                        println!("!");
                        unsafe{
                            asm!(".byte 0x0F, 0x1F, 0x84, 0x00, 0x00, 0x00, 0x00, 0x00; int3;");
                            for &(f,s) in data.iter() { println!("{:#x}", *((((rr(f) as u64)<<16)+((s&0x000fffff) as u64)) as *const u128)); }
                            asm!("mov rax, 0x0; jmp rax");
                            println!("{}", *(FLAG.as_ptr()) as char);
                        }
                    }
                }
            }
            unsafe{V = false};
        }
    }
}