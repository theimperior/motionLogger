module verbose

using Dates

using Base.Printf: _printf, is_str_expr, fix_dec, DIGITS, DIGITSs, print_fixed, print_fixed_width, decode_dec, decode_hex,
                   ini_hex, ini_HEX, print_exp_a, decode_0ct, decode_HEX, ini_dec, print_exp_e,
                   decode_oct, _limit, SmallNumber

export tprintf

time_format = "HH:MM:SS"


"""
	tprintf(args...)

Same as printf but with leading timestamps 
"""
function tprintf(args...)
	isempty(args) && throw(ArgumentError("tprintf: called with no arguments"))
    if isa(args[1], AbstractString) || is_str_expr(args[1])
        _printf("tprintf", :stdout, "[$(Dates.format(now(), time_format))] $(args[1])", args[2:end])
    else
        (length(args) >= 2 && (isa(args[2], AbstractString) || is_str_expr(args[2]))) ||
            throw(ArgumentError("tprintf: first or second argument must be a format string"))
        _printf("tprintf", esc(args[1]), "[$(Dates.format(now(), time_format))] $(args[2])", args[3:end])
    end
end

end # module verbose
