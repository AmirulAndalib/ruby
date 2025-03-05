#ifndef ZJIT_H
#define ZJIT_H 1
//
// This file contains definitions ZJIT exposes to the CRuby codebase
//

#if USE_ZJIT
extern bool rb_zjit_enabled_p;
extern uint64_t rb_zjit_call_threshold;
void rb_zjit_compile_iseq(const rb_iseq_t *iseq, rb_execution_context_t *ec, bool jit_exception);
void rb_zjit_profile_insn(enum ruby_vminsn_type insn, rb_execution_context_t *ec);
void rb_zjit_profile_iseq(const rb_iseq_t *iseq);
void rb_zjit_bop_redefined(int redefined_flag, enum ruby_basic_operators bop);
#else
void rb_zjit_compile_iseq(const rb_iseq_t *iseq, rb_execution_context_t *ec, bool jit_exception) {}
void rb_zjit_profile_insn(enum ruby_vminsn_type insn, rb_execution_context_t *ec) {}
void rb_zjit_profile_iseq(const rb_iseq_t *iseq) {}
void rb_zjit_bop_redefined(int redefined_flag, enum ruby_basic_operators bop) {}
#endif // #if USE_YJIT

#endif // #ifndef ZJIT_H
