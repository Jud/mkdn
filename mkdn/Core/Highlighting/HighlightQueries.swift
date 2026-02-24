// swiftlint:disable file_length type_body_length line_length
/// Embedded tree-sitter highlight query strings for supported languages.
/// Sourced from each grammar's queries/highlights.scm file.
enum HighlightQueries {
    // MARK: - Swift

    static let swift = #"""
    [
      "."
      ";"
      ":"
      ","
    ] @punctuation.delimiter

    [
      "("
      ")"
      "["
      "]"
      "{"
      "}"
    ] @punctuation.bracket

    (type_identifier) @type

    [
      (self_expression)
      (super_expression)
    ] @variable.builtin

    [
      "func"
      "deinit"
    ] @keyword.function

    [
      (visibility_modifier)
      (member_modifier)
      (function_modifier)
      (property_modifier)
      (parameter_modifier)
      (inheritance_modifier)
      (mutation_modifier)
    ] @keyword.modifier

    (simple_identifier) @variable

    (function_declaration
      (simple_identifier) @function.method)

    (protocol_function_declaration
      name: (simple_identifier) @function.method)

    (init_declaration
      "init" @constructor)

    (parameter
      external_name: (simple_identifier) @variable.parameter)

    (parameter
      name: (simple_identifier) @variable.parameter)

    (type_parameter
      (type_identifier) @variable.parameter)

    (inheritance_constraint
      (identifier
        (simple_identifier) @variable.parameter))

    (equality_constraint
      (identifier
        (simple_identifier) @variable.parameter))

    [
      "protocol"
      "extension"
      "indirect"
      "nonisolated"
      "override"
      "convenience"
      "required"
      "some"
      "any"
      "weak"
      "unowned"
      "didSet"
      "willSet"
      "subscript"
      "let"
      "var"
      (throws)
      (where_keyword)
      (getter_specifier)
      (setter_specifier)
      (modify_specifier)
      (else)
      (as_operator)
    ] @keyword

    [
      "enum"
      "struct"
      "class"
      "typealias"
    ] @keyword.type

    [
      "async"
      "await"
    ] @keyword.coroutine

    (shebang_line) @keyword.directive

    (class_body
      (property_declaration
        (pattern
          (simple_identifier) @variable.member)))

    (protocol_property_declaration
      (pattern
        (simple_identifier) @variable.member))

    (navigation_expression
      (navigation_suffix
        (simple_identifier) @variable.member))

    (value_argument
      name: (value_argument_label
        (simple_identifier) @variable.member))

    (import_declaration
      "import" @keyword.import)

    (enum_entry
      "case" @keyword)

    (modifiers
      (attribute
        "@" @attribute
        (user_type
          (type_identifier) @attribute)))

    (call_expression
      (simple_identifier) @function.call)

    (call_expression
      (navigation_expression
        (navigation_suffix
          (simple_identifier) @function.call)))

    (call_expression
      (prefix_expression
        (simple_identifier) @function.call))

    ((navigation_expression
      (simple_identifier) @type)
      (#match? @type "^[A-Z]"))

    (directive) @keyword.directive

    [
      (diagnostic)
      (availability_condition)
      (playground_literal)
      (key_path_string_expression)
      (selector_expression)
      (external_macro_definition)
    ] @function.macro

    (special_literal) @constant.macro

    (for_statement
      "for" @keyword.repeat)

    (for_statement
      "in" @keyword.repeat)

    [
      "while"
      "repeat"
      "continue"
      "break"
    ] @keyword.repeat

    (guard_statement
      "guard" @keyword.conditional)

    (if_statement
      "if" @keyword.conditional)

    (switch_statement
      "switch" @keyword.conditional)

    (switch_entry
      "case" @keyword)

    (switch_entry
      "fallthrough" @keyword)

    (switch_entry
      (default_keyword) @keyword)

    "return" @keyword.return

    (ternary_expression
      [
        "?"
        ":"
      ] @keyword.conditional.ternary)

    [
      (try_operator)
      "do"
      (throw_keyword)
      (catch_keyword)
    ] @keyword.exception

    (statement_label) @label

    [
      (comment)
      (multiline_comment)
    ] @comment

    ((comment) @comment.documentation
      (#match? @comment.documentation "^///[^/]"))

    ((comment) @comment.documentation
      (#match? @comment.documentation "^///$"))

    ((multiline_comment) @comment.documentation
      (#match? @comment.documentation "^/[*][*][^*].*[*]/$"))

    (line_str_text) @string

    (str_escaped_char) @string.escape

    (multi_line_str_text) @string

    (raw_str_part) @string

    (raw_str_end_part) @string

    (line_string_literal
      [
        "\\("
        ")"
      ] @punctuation.special)

    (multi_line_string_literal
      [
        "\\("
        ")"
      ] @punctuation.special)

    (raw_str_interpolation
      [
        (raw_str_interpolation_start)
        ")"
      ] @punctuation.special)

    [
      "\""
      "\"\"\""
    ] @string

    (lambda_literal
      "in" @keyword.operator)

    [
      (integer_literal)
      (hex_literal)
      (oct_literal)
      (bin_literal)
    ] @number

    (real_literal) @number.float

    (boolean_literal) @boolean

    "nil" @constant.builtin

    (wildcard_pattern) @character.special

    (regex_literal) @string.regexp

    (custom_operator) @operator

    [
      "+"
      "-"
      "*"
      "/"
      "%"
      "="
      "+="
      "-="
      "*="
      "/="
      "<"
      ">"
      "<<"
      ">>"
      "<="
      ">="
      "++"
      "--"
      "^"
      "&"
      "&&"
      "|"
      "||"
      "~"
      "%="
      "!="
      "!=="
      "=="
      "==="
      "?"
      "??"
      "->"
      "..<"
      "..."
      (bang)
    ] @operator

    (type_arguments
      [
        "<"
        ">"
      ] @punctuation.bracket)
    """#

    // MARK: - Python

    static let python = #"""
    (identifier) @variable

    ((identifier) @constructor
     (#match? @constructor "^[A-Z]"))

    ((identifier) @constant
     (#match? @constant "^[A-Z][A-Z_]*$"))

    (decorator) @function
    (decorator
      (identifier) @function)

    (call
      function: (attribute attribute: (identifier) @function.method))
    (call
      function: (identifier) @function)

    ((call
      function: (identifier) @function.builtin)
     (#match?
       @function.builtin
       "^(abs|all|any|ascii|bin|bool|breakpoint|bytearray|bytes|callable|chr|classmethod|compile|complex|delattr|dict|dir|divmod|enumerate|eval|exec|filter|float|format|frozenset|getattr|globals|hasattr|hash|help|hex|id|input|int|isinstance|issubclass|iter|len|list|locals|map|max|memoryview|min|next|object|oct|open|ord|pow|print|property|range|repr|reversed|round|set|setattr|slice|sorted|staticmethod|str|sum|super|tuple|type|vars|zip|__import__)$"))

    (function_definition
      name: (identifier) @function)

    (attribute attribute: (identifier) @property)
    (type (identifier) @type)

    [
      (none)
      (true)
      (false)
    ] @constant.builtin

    [
      (integer)
      (float)
    ] @number

    (comment) @comment
    (string) @string
    (escape_sequence) @escape

    (interpolation
      "{" @punctuation.special
      "}" @punctuation.special) @embedded

    [
      "-"
      "-="
      "!="
      "*"
      "**"
      "**="
      "*="
      "/"
      "//"
      "//="
      "/="
      "&"
      "&="
      "%"
      "%="
      "^"
      "^="
      "+"
      "->"
      "+="
      "<"
      "<<"
      "<<="
      "<="
      "<>"
      "="
      ":="
      "=="
      ">"
      ">="
      ">>"
      ">>="
      "|"
      "|="
      "~"
      "@="
      "and"
      "in"
      "is"
      "not"
      "or"
      "is not"
      "not in"
    ] @operator

    [
      "as"
      "assert"
      "async"
      "await"
      "break"
      "class"
      "continue"
      "def"
      "del"
      "elif"
      "else"
      "except"
      "exec"
      "finally"
      "for"
      "from"
      "global"
      "if"
      "import"
      "lambda"
      "nonlocal"
      "pass"
      "print"
      "raise"
      "return"
      "try"
      "while"
      "with"
      "yield"
      "match"
      "case"
    ] @keyword
    """#

    // MARK: - JavaScript

    static let javascript = #"""
    (identifier) @variable

    (property_identifier) @property

    (function_expression
      name: (identifier) @function)
    (function_declaration
      name: (identifier) @function)
    (method_definition
      name: (property_identifier) @function.method)

    (pair
      key: (property_identifier) @function.method
      value: [(function_expression) (arrow_function)])

    (assignment_expression
      left: (member_expression
        property: (property_identifier) @function.method)
      right: [(function_expression) (arrow_function)])

    (variable_declarator
      name: (identifier) @function
      value: [(function_expression) (arrow_function)])

    (assignment_expression
      left: (identifier) @function
      right: [(function_expression) (arrow_function)])

    (call_expression
      function: (identifier) @function)

    (call_expression
      function: (member_expression
        property: (property_identifier) @function.method))

    ((identifier) @constructor
     (#match? @constructor "^[A-Z]"))

    ([
        (identifier)
        (shorthand_property_identifier)
        (shorthand_property_identifier_pattern)
     ] @constant
     (#match? @constant "^[A-Z_][A-Z\\d_]+$"))

    ((identifier) @variable.builtin
     (#match? @variable.builtin "^(arguments|module|console|window|document)$")
     (#is-not? local))

    ((identifier) @function.builtin
     (#eq? @function.builtin "require")
     (#is-not? local))

    (this) @variable.builtin
    (super) @variable.builtin

    [
      (true)
      (false)
      (null)
      (undefined)
    ] @constant.builtin

    (comment) @comment

    [
      (string)
      (template_string)
    ] @string

    (regex) @string.special
    (number) @number

    [
      ";"
      (optional_chain)
      "."
      ","
    ] @punctuation.delimiter

    [
      "-"
      "--"
      "-="
      "+"
      "++"
      "+="
      "*"
      "*="
      "**"
      "**="
      "/"
      "/="
      "%"
      "%="
      "<"
      "<="
      "<<"
      "<<="
      "="
      "=="
      "==="
      "!"
      "!="
      "!=="
      "=>"
      ">"
      ">="
      ">>"
      ">>="
      ">>>"
      ">>>="
      "~"
      "^"
      "&"
      "|"
      "^="
      "&="
      "|="
      "&&"
      "||"
      "??"
      "&&="
      "||="
      "??="
    ] @operator

    [
      "("
      ")"
      "["
      "]"
      "{"
      "}"
    ]  @punctuation.bracket

    (template_substitution
      "${" @punctuation.special
      "}" @punctuation.special) @embedded

    [
      "as"
      "async"
      "await"
      "break"
      "case"
      "catch"
      "class"
      "const"
      "continue"
      "debugger"
      "default"
      "delete"
      "do"
      "else"
      "export"
      "extends"
      "finally"
      "for"
      "from"
      "function"
      "get"
      "if"
      "import"
      "in"
      "instanceof"
      "let"
      "new"
      "of"
      "return"
      "set"
      "static"
      "switch"
      "target"
      "throw"
      "try"
      "typeof"
      "var"
      "void"
      "while"
      "with"
      "yield"
    ] @keyword
    """#

    // MARK: - TypeScript

    /// TypeScript inherits JavaScript queries; TypeScript-specific overrides appended.
    static let typescript = javascript + "\n" + #"""
    (type_identifier) @type
    (predefined_type) @type.builtin

    ((identifier) @type
     (#match? @type "^[A-Z]"))

    (type_arguments
      "<" @punctuation.bracket
      ">" @punctuation.bracket)

    (required_parameter (identifier) @variable.parameter)
    (optional_parameter (identifier) @variable.parameter)

    [ "abstract"
      "declare"
      "enum"
      "export"
      "implements"
      "interface"
      "keyof"
      "namespace"
      "private"
      "protected"
      "public"
      "type"
      "readonly"
      "override"
      "satisfies"
    ] @keyword
    """#

    // MARK: - Rust

    static let rust = #"""
    (type_identifier) @type
    (primitive_type) @type.builtin
    (field_identifier) @property

    ((identifier) @constant
     (#match? @constant "^[A-Z][A-Z\\d_]+$'"))

    ((identifier) @constructor
     (#match? @constructor "^[A-Z]"))

    ((scoped_identifier
      path: (identifier) @type)
     (#match? @type "^[A-Z]"))
    ((scoped_identifier
      path: (scoped_identifier
        name: (identifier) @type))
     (#match? @type "^[A-Z]"))
    ((scoped_type_identifier
      path: (identifier) @type)
     (#match? @type "^[A-Z]"))
    ((scoped_type_identifier
      path: (scoped_identifier
        name: (identifier) @type))
     (#match? @type "^[A-Z]"))

    (struct_pattern
      type: (scoped_type_identifier
        name: (type_identifier) @constructor))

    (call_expression
      function: (identifier) @function)
    (call_expression
      function: (field_expression
        field: (field_identifier) @function.method))
    (call_expression
      function: (scoped_identifier
        "::"
        name: (identifier) @function))

    (generic_function
      function: (identifier) @function)
    (generic_function
      function: (scoped_identifier
        name: (identifier) @function))
    (generic_function
      function: (field_expression
        field: (field_identifier) @function.method))

    (macro_invocation
      macro: (identifier) @function.macro
      "!" @function.macro)

    (function_item (identifier) @function)
    (function_signature_item (identifier) @function)

    (line_comment) @comment
    (block_comment) @comment

    (line_comment (doc_comment)) @comment.documentation
    (block_comment (doc_comment)) @comment.documentation

    "(" @punctuation.bracket
    ")" @punctuation.bracket
    "[" @punctuation.bracket
    "]" @punctuation.bracket
    "{" @punctuation.bracket
    "}" @punctuation.bracket

    (type_arguments
      "<" @punctuation.bracket
      ">" @punctuation.bracket)
    (type_parameters
      "<" @punctuation.bracket
      ">" @punctuation.bracket)

    "::" @punctuation.delimiter
    ":" @punctuation.delimiter
    "." @punctuation.delimiter
    "," @punctuation.delimiter
    ";" @punctuation.delimiter

    (parameter (identifier) @variable.parameter)

    (lifetime (identifier) @label)

    "as" @keyword
    "async" @keyword
    "await" @keyword
    "break" @keyword
    "const" @keyword
    "continue" @keyword
    "default" @keyword
    "dyn" @keyword
    "else" @keyword
    "enum" @keyword
    "extern" @keyword
    "fn" @keyword
    "for" @keyword
    "gen" @keyword
    "if" @keyword
    "impl" @keyword
    "in" @keyword
    "let" @keyword
    "loop" @keyword
    "macro_rules!" @keyword
    "match" @keyword
    "mod" @keyword
    "move" @keyword
    "pub" @keyword
    "raw" @keyword
    "ref" @keyword
    "return" @keyword
    "static" @keyword
    "struct" @keyword
    "trait" @keyword
    "type" @keyword
    "union" @keyword
    "unsafe" @keyword
    "use" @keyword
    "where" @keyword
    "while" @keyword
    "yield" @keyword
    (crate) @keyword
    (mutable_specifier) @keyword
    (use_list (self) @keyword)
    (scoped_use_list (self) @keyword)
    (scoped_identifier (self) @keyword)
    (super) @keyword

    (self) @variable.builtin

    (char_literal) @string
    (string_literal) @string
    (raw_string_literal) @string

    (boolean_literal) @constant.builtin
    (integer_literal) @constant.builtin
    (float_literal) @constant.builtin

    (escape_sequence) @escape

    (attribute_item) @attribute
    (inner_attribute_item) @attribute

    "*" @operator
    "&" @operator
    "'" @operator
    """#

    // MARK: - Go

    static let go = #"""
    (call_expression
      function: (identifier) @function)

    (call_expression
      function: (identifier) @function.builtin
      (#match? @function.builtin "^(append|cap|close|complex|copy|delete|imag|len|make|new|panic|print|println|real|recover)$"))

    (call_expression
      function: (selector_expression
        field: (field_identifier) @function.method))

    (function_declaration
      name: (identifier) @function)

    (method_declaration
      name: (field_identifier) @function.method)

    (type_identifier) @type
    (field_identifier) @property
    (identifier) @variable

    [
      "--"
      "-"
      "-="
      ":="
      "!"
      "!="
      "..."
      "*"
      "*"
      "*="
      "/"
      "/="
      "&"
      "&&"
      "&="
      "%"
      "%="
      "^"
      "^="
      "+"
      "++"
      "+="
      "<-"
      "<"
      "<<"
      "<<="
      "<="
      "="
      "=="
      ">"
      ">="
      ">>"
      ">>="
      "|"
      "|="
      "||"
      "~"
    ] @operator

    [
      "break"
      "case"
      "chan"
      "const"
      "continue"
      "default"
      "defer"
      "else"
      "fallthrough"
      "for"
      "func"
      "go"
      "goto"
      "if"
      "import"
      "interface"
      "map"
      "package"
      "range"
      "return"
      "select"
      "struct"
      "switch"
      "type"
      "var"
    ] @keyword

    [
      (interpreted_string_literal)
      (raw_string_literal)
      (rune_literal)
    ] @string

    (escape_sequence) @escape

    [
      (int_literal)
      (float_literal)
      (imaginary_literal)
    ] @number

    [
      (true)
      (false)
      (nil)
      (iota)
    ] @constant.builtin

    (comment) @comment
    """#

    // MARK: - Bash

    static let bash = #"""
    [
      (string)
      (raw_string)
      (heredoc_body)
      (heredoc_start)
    ] @string

    (command_name) @function

    (variable_name) @property

    [
      "case"
      "do"
      "done"
      "elif"
      "else"
      "esac"
      "export"
      "fi"
      "for"
      "function"
      "if"
      "in"
      "select"
      "then"
      "unset"
      "until"
      "while"
    ] @keyword

    (comment) @comment

    (function_definition name: (word) @function)

    (file_descriptor) @number

    [
      (command_substitution)
      (process_substitution)
      (expansion)
    ] @embedded

    [
      "$"
      "&&"
      ">"
      ">>"
      "<"
      "|"
    ] @operator

    (
      (command (_) @constant)
      (#match? @constant "^-")
    )
    """#

    // MARK: - JSON

    static let json = #"""
    (pair
      key: (_) @string.special.key)

    (string) @string

    (number) @number

    [
      (null)
      (true)
      (false)
    ] @constant.builtin

    (escape_sequence) @escape

    (comment) @comment
    """#

    // MARK: - YAML

    static let yaml = #"""
    (boolean_scalar) @boolean

    (null_scalar) @constant.builtin

    [
      (double_quote_scalar)
      (single_quote_scalar)
      (block_scalar)
      (string_scalar)
    ] @string

    [
      (integer_scalar)
      (float_scalar)
    ] @number

    (comment) @comment

    [
      (anchor_name)
      (alias_name)
    ] @label

    (tag) @type

    [
      (yaml_directive)
      (tag_directive)
      (reserved_directive)
    ] @attribute

    (block_mapping_pair
      key: (flow_node
        [
          (double_quote_scalar)
          (single_quote_scalar)
        ] @property))

    (block_mapping_pair
      key: (flow_node
        (plain_scalar
          (string_scalar) @property)))

    (flow_mapping
      (_
        key: (flow_node
          [
            (double_quote_scalar)
            (single_quote_scalar)
          ] @property)))

    (flow_mapping
      (_
        key: (flow_node
          (plain_scalar
            (string_scalar) @property))))

    [
      ","
      "-"
      ":"
      ">"
      "?"
      "|"
    ] @punctuation.delimiter

    [
      "["
      "]"
      "{"
      "}"
    ] @punctuation.bracket

    [
      "*"
      "&"
      "---"
      "..."
    ] @punctuation.special
    """#

    // MARK: - HTML

    static let html = #"""
    (tag_name) @tag
    (erroneous_end_tag_name) @tag.error
    (doctype) @constant
    (attribute_name) @attribute
    (attribute_value) @string
    (comment) @comment

    [
      "<"
      ">"
      "</"
      "/>"
    ] @punctuation.bracket
    """#

    // MARK: - CSS

    static let css = #"""
    (comment) @comment

    (tag_name) @tag
    (nesting_selector) @tag
    (universal_selector) @tag

    "~" @operator
    ">" @operator
    "+" @operator
    "-" @operator
    "*" @operator
    "/" @operator
    "=" @operator
    "^=" @operator
    "|=" @operator
    "~=" @operator
    "$=" @operator
    "*=" @operator

    "and" @operator
    "or" @operator
    "not" @operator
    "only" @operator

    (attribute_selector (plain_value) @string)
    (pseudo_element_selector (tag_name) @attribute)
    (pseudo_class_selector (class_name) @attribute)

    (class_name) @property
    (id_name) @property
    (namespace_name) @property
    (property_name) @property
    (feature_name) @property

    (attribute_name) @attribute

    (function_name) @function

    ((property_name) @variable
     (#match? @variable "^--"))
    ((plain_value) @variable
     (#match? @variable "^--"))

    "@media" @keyword
    "@import" @keyword
    "@charset" @keyword
    "@namespace" @keyword
    "@supports" @keyword
    "@keyframes" @keyword
    (at_keyword) @keyword
    (to) @keyword
    (from) @keyword
    (important) @keyword

    (string_value) @string
    (color_value) @string.special

    (integer_value) @number
    (float_value) @number
    (unit) @type

    "#" @punctuation.delimiter
    "," @punctuation.delimiter
    ":" @punctuation.delimiter
    """#

    // MARK: - C

    static let cLang = #"""
    (identifier) @variable

    ((identifier) @constant
     (#match? @constant "^[A-Z][A-Z\\d_]*$"))

    "break" @keyword
    "case" @keyword
    "const" @keyword
    "continue" @keyword
    "default" @keyword
    "do" @keyword
    "else" @keyword
    "enum" @keyword
    "extern" @keyword
    "for" @keyword
    "if" @keyword
    "inline" @keyword
    "return" @keyword
    "sizeof" @keyword
    "static" @keyword
    "struct" @keyword
    "switch" @keyword
    "typedef" @keyword
    "union" @keyword
    "volatile" @keyword
    "while" @keyword

    "#define" @keyword
    "#elif" @keyword
    "#else" @keyword
    "#endif" @keyword
    "#if" @keyword
    "#ifdef" @keyword
    "#ifndef" @keyword
    "#include" @keyword
    (preproc_directive) @keyword

    "--" @operator
    "-" @operator
    "-=" @operator
    "->" @operator
    "=" @operator
    "!=" @operator
    "*" @operator
    "&" @operator
    "&&" @operator
    "+" @operator
    "++" @operator
    "+=" @operator
    "<" @operator
    "==" @operator
    ">" @operator
    "||" @operator

    "." @punctuation.delimiter
    ";" @punctuation.delimiter

    (string_literal) @string
    (system_lib_string) @string

    (null) @constant
    (number_literal) @number
    (char_literal) @number

    (field_identifier) @property
    (statement_identifier) @label
    (type_identifier) @type
    (primitive_type) @type
    (sized_type_specifier) @type

    (call_expression
      function: (identifier) @function)
    (call_expression
      function: (field_expression
        field: (field_identifier) @function))
    (function_declarator
      declarator: (identifier) @function)
    (preproc_function_def
      name: (identifier) @function.special)

    (comment) @comment
    """#

    // MARK: - C++

    /// C++ inherits C queries; C++-specific overrides appended.
    static let cpp = cLang + "\n" + #"""
    (call_expression
      function: (qualified_identifier
        name: (identifier) @function))

    (template_function
      name: (identifier) @function)

    (template_method
      name: (field_identifier) @function)

    (function_declarator
      declarator: (qualified_identifier
        name: (identifier) @function))

    (function_declarator
      declarator: (field_identifier) @function)

    ((namespace_identifier) @type
     (#match? @type "^[A-Z]"))

    (auto) @type

    (this) @variable.builtin
    (null "nullptr" @constant)

    [
     "catch"
     "class"
     "co_await"
     "co_return"
     "co_yield"
     "constexpr"
     "constinit"
     "consteval"
     "delete"
     "explicit"
     "final"
     "friend"
     "mutable"
     "namespace"
     "noexcept"
     "new"
     "override"
     "private"
     "protected"
     "public"
     "template"
     "throw"
     "try"
     "typename"
     "using"
     "concept"
     "requires"
     "virtual"
    ] @keyword

    (raw_string_literal) @string
    """#

    // MARK: - Ruby

    static let ruby = #"""
    (identifier) @variable

    ((identifier) @function.method
     (#is-not? local))

    [
      "alias"
      "and"
      "begin"
      "break"
      "case"
      "class"
      "def"
      "do"
      "else"
      "elsif"
      "end"
      "ensure"
      "for"
      "if"
      "in"
      "module"
      "next"
      "or"
      "rescue"
      "retry"
      "return"
      "then"
      "unless"
      "until"
      "when"
      "while"
      "yield"
    ] @keyword

    ((identifier) @keyword
     (#match? @keyword "^(private|protected|public)$"))

    (constant) @constructor

    "defined?" @function.method.builtin

    (call
      method: [(identifier) (constant)] @function.method)

    ((identifier) @function.method.builtin
     (#eq? @function.method.builtin "require"))

    (alias (identifier) @function.method)
    (setter (identifier) @function.method)
    (method name: [(identifier) (constant)] @function.method)
    (singleton_method name: [(identifier) (constant)] @function.method)

    [
      (class_variable)
      (instance_variable)
    ] @property

    ((identifier) @constant.builtin
     (#match? @constant.builtin "^__(FILE|LINE|ENCODING)__$"))

    (file) @constant.builtin
    (line) @constant.builtin
    (encoding) @constant.builtin

    (hash_splat_nil
      "**" @operator) @constant.builtin

    ((constant) @constant
     (#match? @constant "^[A-Z\\d_]+$"))

    [
      (self)
      (super)
    ] @variable.builtin

    (block_parameter (identifier) @variable.parameter)
    (block_parameters (identifier) @variable.parameter)
    (destructured_parameter (identifier) @variable.parameter)
    (hash_splat_parameter (identifier) @variable.parameter)
    (lambda_parameters (identifier) @variable.parameter)
    (method_parameters (identifier) @variable.parameter)
    (splat_parameter (identifier) @variable.parameter)

    (keyword_parameter name: (identifier) @variable.parameter)
    (optional_parameter name: (identifier) @variable.parameter)

    [
      (string)
      (bare_string)
      (subshell)
      (heredoc_body)
      (heredoc_beginning)
    ] @string

    [
      (simple_symbol)
      (delimited_symbol)
      (hash_key_symbol)
      (bare_symbol)
    ] @string.special.symbol

    (regex) @string.special.regex
    (escape_sequence) @escape

    [
      (integer)
      (float)
    ] @number

    [
      (nil)
      (true)
      (false)
    ] @constant.builtin

    (interpolation
      "#{" @punctuation.special
      "}" @punctuation.special) @embedded

    (comment) @comment

    [
    "="
    "=>"
    "->"
    ] @operator

    [
      ","
      ";"
      "."
    ] @punctuation.delimiter

    [
      "("
      ")"
      "["
      "]"
      "{"
      "}"
      "%w("
      "%i("
    ] @punctuation.bracket
    """#

    // MARK: - Java

    static let java = #"""
    (identifier) @variable

    (method_declaration
      name: (identifier) @function.method)
    (method_invocation
      name: (identifier) @function.method)
    (super) @function.builtin

    (annotation
      name: (identifier) @attribute)
    (marker_annotation
      name: (identifier) @attribute)

    "@" @operator

    (type_identifier) @type

    (interface_declaration
      name: (identifier) @type)
    (class_declaration
      name: (identifier) @type)
    (enum_declaration
      name: (identifier) @type)

    ((field_access
      object: (identifier) @type)
     (#match? @type "^[A-Z]"))
    ((scoped_identifier
      scope: (identifier) @type)
     (#match? @type "^[A-Z]"))
    ((method_invocation
      object: (identifier) @type)
     (#match? @type "^[A-Z]"))
    ((method_reference
      . (identifier) @type)
     (#match? @type "^[A-Z]"))

    (constructor_declaration
      name: (identifier) @type)

    [
      (boolean_type)
      (integral_type)
      (floating_point_type)
      (floating_point_type)
      (void_type)
    ] @type.builtin

    ((identifier) @constant
     (#match? @constant "^_*[A-Z][A-Z\\d_]+$"))

    (this) @variable.builtin

    [
      (hex_integer_literal)
      (decimal_integer_literal)
      (octal_integer_literal)
      (decimal_floating_point_literal)
      (hex_floating_point_literal)
    ] @number

    [
      (character_literal)
      (string_literal)
    ] @string
    (escape_sequence) @string.escape

    [
      (true)
      (false)
      (null_literal)
    ] @constant.builtin

    [
      (line_comment)
      (block_comment)
    ] @comment

    [
      "abstract"
      "assert"
      "break"
      "case"
      "catch"
      "class"
      "continue"
      "default"
      "do"
      "else"
      "enum"
      "exports"
      "extends"
      "final"
      "finally"
      "for"
      "if"
      "implements"
      "import"
      "instanceof"
      "interface"
      "module"
      "native"
      "new"
      "non-sealed"
      "open"
      "opens"
      "package"
      "permits"
      "private"
      "protected"
      "provides"
      "public"
      "requires"
      "record"
      "return"
      "sealed"
      "static"
      "strictfp"
      "switch"
      "synchronized"
      "throw"
      "throws"
      "to"
      "transient"
      "transitive"
      "try"
      "uses"
      "volatile"
      "when"
      "while"
      "with"
      "yield"
    ] @keyword
    """#

    // MARK: - Kotlin

    static let kotlin = #"""
    (simple_identifier) @variable

    ((simple_identifier) @variable.builtin
    (#eq? @variable.builtin "it"))

    ((simple_identifier) @variable.builtin
    (#eq? @variable.builtin "field"))

    (this_expression) @variable.builtin

    (super_expression) @variable.builtin

    (class_parameter
    	(simple_identifier) @property)

    (class_body
    	(property_declaration
    		(variable_declaration
    			(simple_identifier) @property)))

    (_
    	(navigation_suffix
    		(simple_identifier) @property))

    (enum_entry
    	(simple_identifier) @constant)

    (type_identifier) @type

    ((type_identifier) @type.builtin
    	(#any-of? @type.builtin
    		"Byte"
    		"Short"
    		"Int"
    		"Long"
    		"UByte"
    		"UShort"
    		"UInt"
    		"ULong"
    		"Float"
    		"Double"
    		"Boolean"
    		"Char"
    		"String"
    		"Array"
    		"ByteArray"
    		"ShortArray"
    		"IntArray"
    		"LongArray"
    		"UByteArray"
    		"UShortArray"
    		"UIntArray"
    		"ULongArray"
    		"FloatArray"
    		"DoubleArray"
    		"BooleanArray"
    		"CharArray"
    		"Map"
    		"Set"
    		"List"
    		"EmptyMap"
    		"EmptySet"
    		"EmptyList"
    		"MutableMap"
    		"MutableSet"
    		"MutableList"
    ))

    (package_header
    	. (identifier)) @namespace

    (import_header
    	"import" @include)

    (label) @label

    (function_declaration
    	. (simple_identifier) @function)

    (getter
    	("get") @function.builtin)
    (setter
    	("set") @function.builtin)

    (primary_constructor) @constructor
    (secondary_constructor
    	("constructor") @constructor)

    (constructor_invocation
    	(user_type
    		(type_identifier) @constructor))

    (anonymous_initializer
    	("init") @constructor)

    (parameter
    	(simple_identifier) @parameter)

    (parameter_with_optional_type
    	(simple_identifier) @parameter)

    (lambda_literal
    	(lambda_parameters
    		(variable_declaration
    			(simple_identifier) @parameter)))

    (call_expression
    	. (simple_identifier) @function)

    (call_expression
    	(navigation_expression
    		(navigation_suffix
    			(simple_identifier) @function) . ))

    (call_expression
    	. (simple_identifier) @function.builtin
        (#any-of? @function.builtin
    		"arrayOf"
    		"arrayOfNulls"
    		"byteArrayOf"
    		"shortArrayOf"
    		"intArrayOf"
    		"longArrayOf"
    		"ubyteArrayOf"
    		"ushortArrayOf"
    		"uintArrayOf"
    		"ulongArrayOf"
    		"floatArrayOf"
    		"doubleArrayOf"
    		"booleanArrayOf"
    		"charArrayOf"
    		"emptyArray"
    		"mapOf"
    		"setOf"
    		"listOf"
    		"emptyMap"
    		"emptySet"
    		"emptyList"
    		"mutableMapOf"
    		"mutableSetOf"
    		"mutableListOf"
    		"print"
    		"println"
    		"error"
    		"TODO"
    		"run"
    		"runCatching"
    		"repeat"
    		"lazy"
    		"lazyOf"
    		"enumValues"
    		"enumValueOf"
    		"assert"
    		"check"
    		"checkNotNull"
    		"require"
    		"requireNotNull"
    		"with"
    		"suspend"
    		"synchronized"
    ))

    [
    	(line_comment)
    	(multiline_comment)
    	(shebang_line)
    ] @comment

    (real_literal) @number.float
    [
    	(integer_literal)
    	(long_literal)
    	(hex_literal)
    	(bin_literal)
    	(unsigned_literal)
    ] @number

    [
    	"null"
    	(boolean_literal)
    ] @boolean

    (character_literal) @character

    (string_literal) @string

    (character_escape_seq) @string.escape

    (call_expression
    	(navigation_expression
    		((string_literal) @string.regex)
    		(navigation_suffix
    			((simple_identifier) @_function
    			(#eq? @_function "toRegex")))))

    (call_expression
    	((simple_identifier) @_function
    	(#eq? @_function "Regex"))
    	(call_suffix
    		(value_arguments
    			(value_argument
    				(string_literal) @string.regex))))

    (call_expression
    	(navigation_expression
    		((simple_identifier) @_class
    		(#eq? @_class "Regex"))
    		(navigation_suffix
    			((simple_identifier) @_function
    			(#eq? @_function "fromLiteral"))))
    	(call_suffix
    		(value_arguments
    			(value_argument
    				(string_literal) @string.regex))))

    (type_alias "typealias" @keyword)
    [
    	(class_modifier)
    	(member_modifier)
    	(function_modifier)
    	(property_modifier)
    	(platform_modifier)
    	(variance_modifier)
    	(parameter_modifier)
    	(visibility_modifier)
    	(reification_modifier)
    	(inheritance_modifier)
    ] @keyword

    [
    	"val"
    	"var"
    	"enum"
    	"class"
    	"object"
    	"interface"
    ] @keyword

    ("fun") @keyword

    (jump_expression) @keyword

    [
    	"if"
    	"else"
    	"when"
    ] @keyword

    [
    	"for"
    	"do"
    	"while"
    ] @keyword

    [
    	"try"
    	"catch"
    	"throw"
    	"finally"
    ] @keyword

    (annotation
    	"@" @attribute (use_site_target)? @attribute)
    (annotation
    	(user_type
    		(type_identifier) @attribute))
    (annotation
    	(constructor_invocation
    		(user_type
    			(type_identifier) @attribute)))

    (file_annotation
    	"@" @attribute "file" @attribute ":" @attribute)
    (file_annotation
    	(user_type
    		(type_identifier) @attribute))
    (file_annotation
    	(constructor_invocation
    		(user_type
    			(type_identifier) @attribute)))

    [
    	"!"
    	"!="
    	"!=="
    	"="
    	"=="
    	"==="
    	">"
    	">="
    	"<"
    	"<="
    	"||"
    	"&&"
    	"+"
    	"++"
    	"+="
    	"-"
    	"--"
    	"-="
    	"*"
    	"*="
    	"/"
    	"/="
    	"%"
    	"%="
    	"?."
    	"?:"
    	"!!"
    	"is"
    	"!is"
    	"in"
    	"!in"
    	"as"
    	"as?"
    	".."
    	"->"
    ] @operator

    [
    	"(" ")"
    	"[" "]"
    	"{" "}"
    ] @punctuation.bracket

    [
    	"."
    	","
    	";"
    	":"
    	"::"
    ] @punctuation.delimiter

    (string_literal
    	"$" @punctuation.special
    	(interpolated_identifier) @variable)
    (string_literal
    	"${" @punctuation.special
    	(interpolated_expression) @variable
    	"}" @punctuation.special)
    """#
}

// swiftlint:enable file_length type_body_length line_length
