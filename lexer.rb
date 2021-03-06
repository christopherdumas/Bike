def to_fi(v)
  v.match('\.').nil? ? Integer(v) : Float(v)
end
class Lexer
  KEYWORDS = ["data", "var", "def", "class", "if", "let", "else", "true", "false", "nil", "while", "unless", "apply", "extends", "import", "into", "package", "with", "mixin", "hash", "private", "elsif", "for", "of"]

  def tokenize(code)
    code.chomp!
    i = 0
    tokens = []

    while i < code.size
      chunk = code[i..-1]
      if comment = chunk[/\A#\|.*\|#/]
        i += comment.size
      elsif comment = chunk[/\A#.*$/]
        i += comment.size
      elsif identifier = chunk[/\A([a-zA-Z_](\w|&|=)*)/, 1]
        if KEYWORDS.include?(identifier)
          tokens << [identifier.upcase.to_sym, identifier]
        else
          tokens << [:IDENTIFIER, identifier]
        end
        i += identifier.size
      elsif operator = chunk[/\A(%|@|=@|isnt|or|and|not|is|<=|>=|->|=>|\\|\$|\:|\|\>|\<\|\>)/, 1]
        if operator == "->"
          tokens << [:ARROW, "arrow"]
        elsif operator == "=>"
          tokens << [:ROCKET, "rocket"]
        elsif operator == "=@"
          tokens << ["set", "set"]
        elsif operator == "\\"
          tokens << [:SLASH, "slash"]
        elsif operator == "$"
          tokens << [:APPLY, "apply"]
        else
          tokens << [operator, operator]
        end
        i += operator.size
      elsif number = chunk[/\A([-+]?[0-9]+\.?[0-9]*)/, 1]
        tokens << [:NUMBER, to_fi(number)]
        i += number.size
      elsif string = chunk[/\A"(.*?)"/, 1]
        tokens << [:STRING, string]
        i += string.size + 2
       elsif string = chunk[/\A'(.*?)'/, 1]
        tokens << [:STRING, string]
        i += string.size + 2
      elsif chunk.match(/\A\n+/)
        tokens << [:NEWLINE, "\n"]
        i += 1
      elsif chunk.match(/\A\s+/)
        i += 1
      else
        value = chunk[0,1]
        tokens << [value, value]
        i += 1
      end
    end
    tokens
  end
end
