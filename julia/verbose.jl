module verbose

export @tprintf




"""
	tprintf(args...)

Same as printf but with leading timestamps 
"""
macro tprintf(args...)
	isempty(args) && throw(ArgumentError("@printf: called with no arguments"))
    if isa(args[1], AbstractString) || is_str_expr(args[1])
        _printf("@printf", :stdout, "[$(Dates.format(now(), time_format))]$(args[1])", args[2:end])
    else
        (length(args) >= 2 && (isa(args[2], AbstractString) || is_str_expr(args[2]))) ||
            throw(ArgumentError("@printf: first or second argument must be a format string"))
        _printf("@printf", esc(args[1]), "[$(Dates.format(now(), time_format))]$(args[2])", args[3:end])
    end
end

end # module verbose