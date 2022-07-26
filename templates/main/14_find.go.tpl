{{- if .Table.IsView -}}
{{- else -}}
{{- $alias := .Aliases.Table .Table.Name -}}
{{- $colDefs := sqlColDefinitions .Table.Columns .Table.PKey.Columns -}}
{{- $pkNames := $colDefs.Names | stringMap (aliasCols $alias) | stringMap .StringFuncs.camelCase | stringMap .StringFuncs.replaceReserved -}}
{{- $pkArgs := joinSlices " " $pkNames $colDefs.Types | join ", " -}}
{{- $canSoftDelete := .Table.CanSoftDelete $.AutoColumns.Deleted }}
{{if .AddGlobal -}}
// Find{{$alias.UpSingular}}G retrieves a single record by ID.
func Find{{$alias.UpSingular}}G(ctx context.Context, {{$pkArgs}}, selectCols ...string) (*{{$alias.UpSingular}}, error) {
	return Find{{$alias.UpSingular}}(ctx, boil.GetContextDB(), {{$pkNames | join ", "}}, selectCols...)
}

{{end -}}

{{if .AddPanic -}}
// Find{{$alias.UpSingular}}P retrieves a single record by ID with an executor, and panics on error.
func Find{{$alias.UpSingular}}P(ctx context.Context, exec boil.ContextExecutor, {{$pkArgs}}, selectCols ...string) *{{$alias.UpSingular}} {
	retobj, err := Find{{$alias.UpSingular}}(ctx,  exec, {{$pkNames | join ", "}}, selectCols...)
	if err != nil {
		panic(boil.WrapErr(err))
	}

	return retobj
}

{{end -}}

{{if and .AddGlobal .AddPanic -}}
// Find{{$alias.UpSingular}}GP retrieves a single record by ID, and panics on error.
func Find{{$alias.UpSingular}}GP(ctx context.Context, {{$pkArgs}}, selectCols ...string) *{{$alias.UpSingular}} {
	retobj, err := Find{{$alias.UpSingular}}(ctx, boil.GetContextDB(), {{$pkNames | join ", "}}, selectCols...)
	if err != nil {
		panic(boil.WrapErr(err))
	}

	return retobj
}

{{end -}}

// Find{{$alias.UpSingular}} retrieves a single record by ID with an executor.
// If selectCols is empty Find will return all columns.
func Find{{$alias.UpSingular}}(ctx context.Context, exec boil.ContextExecutor, {{$pkArgs}}, selectCols ...string) (*{{$alias.UpSingular}}, error) {
	{{$alias.DownSingular}}Obj := &{{$alias.UpSingular}}{}

	sel := "*"
	if len(selectCols) > 0 {
		sel = strings.Join(strmangle.IdentQuoteSlice(dialect.LQ, dialect.RQ, selectCols), ",")
	}
	query := fmt.Sprintf(
		"select %s from {{.Table.Name | .SchemaTable}} where {{if .Dialect.UseIndexPlaceholders}}{{whereClause .LQ .RQ 1 .Table.PKey.Columns}}{{else}}{{whereClause .LQ .RQ 0 .Table.PKey.Columns}}{{end}}{{if and .AddSoftDeletes $canSoftDelete}} and {{or $.AutoColumns.Deleted "deleted_at" | $.Quotes}} is null{{end}}", sel,
	)

	q := queries.Raw(query, {{$pkNames | join ", "}})

	err := q.Bind(ctx, exec, {{$alias.DownSingular}}Obj)
	if err != nil {
		{{if not .AlwaysWrapErrors -}}
		if errors.Is(err, sql.ErrNoRows) {
			return nil, sql.ErrNoRows
		}
		{{end -}}
		return nil, errors.Wrap(err, "{{.PkgName}}: unable to select from {{.Table.Name}}")
	}

	if err = {{$alias.DownSingular}}Obj.doAfterSelectHooks(ctx,  exec); err != nil {
		return {{$alias.DownSingular}}Obj, err
	}

	return {{$alias.DownSingular}}Obj, nil
}

{{- end -}}
