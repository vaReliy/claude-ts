# Shell Scripting Rules

## EXIT Trap with Local Variables and `set -u`

Under `set -u` (nounset), if a function defines local variables and sets an EXIT trap that references those locals, the trap will fail during function unwinding. When the function exits (especially on `set -e` errexit), bash tears down the function's local scope *before* the trap runs, causing the trap's variable references to be unbound.

**Solution**: Declare trap variables at function scope, not as locals. Alternatively, use explicit cleanup and reset the trap before function return:

```bash
trap 'rm -f "$var1" "$var2"' EXIT
# ... function body ...
rm -f "$var1" "$var2"  # explicit cleanup
trap - EXIT            # reset the trap before return
```

See `merge_one()` in `.claude/scripts/cts-sync.sh` for a working example.

## Prettier CLI Binary Resolution

When symlinking prettier into a fixture or temporary directory for testing, symlinking only `node_modules/.bin/prettier` is insufficient. Prettier's CLI bin shim resolves its module via realpath of the **invoked binary location**, not the symlink path. This causes MODULE_NOT_FOUND for the prettier module itself.

**Solution**: Symlink the entire `node_modules` directory, not just the `.bin/prettier` executable.

## Prettier 3.5+ Object Wrap Default

Prettier 3.5+ changed the default value of `objectWrap` from `always` to `preserve`. In test fixtures that compare normalized content before/after formatting, object-wrap style will no longer converge to a common form. Tests relying on JSON or object-literal normalization must account for this.

**Solution**: Use a formatting axis that prettier *will* unconditionally normalize (e.g., indent width changes), not object-wrap style. Alternatively, explicitly pin `objectWrap: always` in the prettier config used by tests.
