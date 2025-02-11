#![allow(dead_code)]
#![allow(static_mut_refs)]

mod codegen;
mod cruby;
mod ir;
mod stats;
mod utils;
mod virtualmem;
mod asm;
mod backend;
mod disasm;
mod options;

use codegen::ZJITState;
use options::get_option;
use crate::cruby::*;

#[allow(non_upper_case_globals)]
#[no_mangle]
pub static mut rb_zjit_enabled_p: bool = false;

/// Initialize ZJIT, given options allocated by rb_zjit_init_options()
#[no_mangle]
pub extern "C" fn rb_zjit_init(options: *const u8) {
    // Catch panics to avoid UB for unwinding into C frames.
    // See https://doc.rust-lang.org/nomicon/exception-safety.html
    let result = std::panic::catch_unwind(|| {
        ZJITState::init(options);

        rb_bug_panic_hook();

        // YJIT enabled and initialized successfully
        assert!(unsafe{ !rb_zjit_enabled_p });
        unsafe { rb_zjit_enabled_p = true; }
    });

    if let Err(_) = result {
        println!("ZJIT: zjit_init() panicked. Aborting.");
        std::process::abort();
    }
}

/// At the moment, we abort in all cases we panic.
/// To aid with getting diagnostics in the wild without requiring
/// people to set RUST_BACKTRACE=1, register a panic hook that crash using rb_bug().
/// rb_bug() might not be as good at printing a call trace as Rust's stdlib, but
/// it dumps some other info that might be relevant.
///
/// In case we want to start doing fancier exception handling with panic=unwind,
/// we can revisit this later. For now, this helps to get us good bug reports.
fn rb_bug_panic_hook() {
    use std::env;
    use std::panic;
    use std::io::{stderr, Write};

    // Probably the default hook. We do this very early during process boot.
    let previous_hook = panic::take_hook();

    panic::set_hook(Box::new(move |panic_info| {
        // Not using `eprintln` to avoid double panic.
        let _ = stderr().write_all(b"ruby: ZJIT has panicked. More info to follow...\n");

        // Always show a Rust backtrace.
        env::set_var("RUST_BACKTRACE", "1");
        previous_hook(panic_info);

        // TODO: enable CRuby's SEGV handler
        // Abort with rb_bug(). It has a length limit on the message.
        //let panic_message = &format!("{}", panic_info)[..];
        //let len = std::cmp::min(0x100, panic_message.len()) as c_int;
        //unsafe { rb_bug(b"ZJIT: %*s\0".as_ref().as_ptr() as *const c_char, len, panic_message.as_ptr()); }
    }));
}

#[no_mangle]
pub extern "C" fn rb_zjit_iseq_gen_entry_point(iseq: IseqPtr, _ec: EcPtr) -> *const u8 {
    ir::iseq_to_ssa(iseq).unwrap();

    let cb = ZJITState::get_code_block();
    let start_ptr = cb.get_write_ptr();
    //x86_emit(cb);

    #[cfg(feature = "disasm")]
    if get_option!(dump_disasm) {
        let end_ptr = cb.get_write_ptr();
        let disasm = disasm::disasm_addr_range(start_ptr.raw_ptr(cb) as usize, end_ptr.raw_ptr(cb) as usize);
        println!("{}", disasm);
    }

    if cfg!(target_arch = "x86_64") {
        start_ptr.raw_ptr(cb)
    } else {
        std::ptr::null()
    }
}
