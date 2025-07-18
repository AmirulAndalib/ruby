#ifndef INTERNAL_VARIABLE_H                              /*-*-C-*-vi:se ft=c:*/
#define INTERNAL_VARIABLE_H
/**
 * @author     Ruby developers <ruby-core@ruby-lang.org>
 * @copyright  This  file  is   a  part  of  the   programming  language  Ruby.
 *             Permission  is hereby  granted,  to  either redistribute  and/or
 *             modify this file, provided that  the conditions mentioned in the
 *             file COPYING are met.  Consult the file for details.
 * @brief      Internal header for variables.
 */
#include "ruby/internal/config.h"
#include <stddef.h>             /* for size_t */
#include "constant.h"           /* for rb_const_entry_t */
#include "ruby/internal/stdbool.h"     /* for bool */
#include "ruby/ruby.h"          /* for VALUE */
#include "shape.h"              /* for shape_id_t */

/* variable.c */
void rb_gc_mark_global_tbl(void);
void rb_gc_update_global_tbl(void);
VALUE rb_search_class_path(VALUE);
VALUE rb_attr_delete(VALUE, ID);
void rb_autoload_str(VALUE mod, ID id, VALUE file);
VALUE rb_autoload_at_p(VALUE, ID, int);
void rb_autoload_copy_table_for_namespace(st_table *, const rb_namespace_t *);
NORETURN(VALUE rb_mod_const_missing(VALUE,VALUE));
rb_gvar_getter_t *rb_gvar_getter_function_of(ID);
rb_gvar_setter_t *rb_gvar_setter_function_of(ID);
void rb_gvar_readonly_setter(VALUE v, ID id, VALUE *_);
void rb_gvar_ractor_local(const char *name);
void rb_gvar_namespace_ready(const char *name);

/**
 * Sets the name of a module.
 *
 * Non-permanently named classes can have a temporary name assigned (or
 * cleared). In that case the name will be used for `#inspect` and `#to_s`, and
 * nested classes/modules will be named with the temporary name as a prefix.
 *
 * After the module is assigned to a constant, the temporary name will be
 * discarded, and the name will be computed based on the nesting.
 *
 * @param[in]  mod        An instance of ::rb_cModule.
 * @param[in]  name       An instance of ::rb_cString.
 * @retval     mod
 */
VALUE rb_mod_set_temporary_name(VALUE, VALUE);

int rb_gen_fields_tbl_get(VALUE obj, ID id, VALUE *fields_obj);
void rb_obj_copy_ivs_to_hash_table(VALUE obj, st_table *table);
void rb_obj_init_too_complex(VALUE obj, st_table *table);
void rb_evict_ivars_to_hash(VALUE obj);
shape_id_t rb_evict_fields_to_hash(VALUE obj);
VALUE rb_obj_field_get(VALUE obj, shape_id_t target_shape_id);
void rb_ivar_set_internal(VALUE obj, ID id, VALUE val);
void rb_obj_field_set(VALUE obj, shape_id_t target_shape_id, ID field_name, VALUE val);

RUBY_SYMBOL_EXPORT_BEGIN
/* variable.c (export) */
void rb_mark_generic_ivar(VALUE obj);
VALUE rb_const_missing(VALUE klass, VALUE name);
bool rb_class_ivar_set(VALUE klass, ID vid, VALUE value);
void rb_fields_tbl_copy(VALUE dst, VALUE src);
RUBY_SYMBOL_EXPORT_END

VALUE rb_ivar_lookup(VALUE obj, ID id, VALUE undef);
VALUE rb_gvar_get(ID);
VALUE rb_gvar_set(ID, VALUE);
VALUE rb_gvar_defined(ID);
void rb_const_warn_if_deprecated(const rb_const_entry_t *, VALUE, ID);
void rb_ensure_iv_list_size(VALUE obj, uint32_t current_len, uint32_t newsize);
attr_index_t rb_obj_ivar_set(VALUE obj, ID id, VALUE val);

#endif /* INTERNAL_VARIABLE_H */
