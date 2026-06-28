# SQL Preview Design Notes

- `peek` treats plain `.sql` files as generic SQL by default.
- Explicit dialect overrides are exposed as `sql`, `sqlite`, `postgres`, and `mysql`.
- The previewer is color-only and source-preserving after ANSI stripping.
- Dialect-specific behavior lives in `peek-lib/peek/sql.rkt`; generic preview dispatch stays in `peek-lib/peek/preview.rkt`.
