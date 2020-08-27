  /*
   *  The scanner definition for COOL.
   *
   *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
   *  output, so headers and global definitions are placed here to be visible
   * to the code in the file.  Don't remove anything that was here initially
   */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

/*
 *  Add Your own definitions here
 */
#define ERR_STR_UNTERMINATED  "Unterminated string constant"
#define ERR_STR_TOO_LONG      "String constant too long"
#define ERR_STR_HAS_NULL      "String contains null character"
#define ERR_STR_HAS_EOF       "EOF in string constant"
#define ERR_CMT_HAS_EOF       "EOF in comment"
#define ERR_CMT_INVALID_CLOSE "Unmatched *)"

inline void consume_invalid_str(int &lineno);
inline void assign_err_msg(char* msg);

char* const string_buf_end = &string_buf[MAX_STR_CONST];
int nest_comment_level = 0;
%}

%x comment inline_comment str_literal
SINGLE_OP  [\,\.\@\~\*\/\+\-\<\=\:\;\(\)\{\}]

%%

 /*
  *  The multiple-character operators.
  */
\=\> {
  return DARROW;
}
\<\- {
  return ASSIGN;
}
\<\= {
  return LE;
}

 /*
  *  The single-character operators.
  */
{SINGLE_OP} {
  return int(yytext[0]);
}

 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */
(?i:class) {
  return CLASS;
}
(?i:else) {
  return ELSE;
}
(?i:fi) {
  return FI;
}
(?i:if) {
  return IF;
}
(?i:in) {
  return IN;
}
(?i:inherits) {
  return INHERITS;
}
(?i:isvoid) {
  return ISVOID;
}
(?i:loop) {
  return LOOP;
}
(?i:pool) {
  return POOL;
}
(?i:then) {
  return THEN;
}
(?i:while) {
  return WHILE;
}
(?i:case) {
  return CASE;
}
(?i:esac) {
  return ESAC;
}
(?i:new) {
  return NEW;
}
(?i:of) {
  return OF;
}
(?i:not) {
  return NOT;
}
(?i:let) {
  return LET_STMT;
}
t(?i:rue) {
  cool_yylval.boolean = true;
  return BOOL_CONST;
}
f(?i:alse) {
  cool_yylval.boolean = false;
  return BOOL_CONST;
}
error { }

 /*
  *  Contans and identifiers
  */
[[:digit:]]+ {
  cool_yylval.symbol = inttable.add_string(yytext);
  return INT_CONST;
}
self {
  cool_yylval.symbol = idtable.add_string(yytext);
  return OBJECTID;
}
SELF_TYPE {
  cool_yylval.symbol = idtable.add_string(yytext);
  return TYPEID;
}
[[:upper:]][[:alnum:]_]* {
  cool_yylval.symbol = idtable.add_string(yytext);
  return TYPEID;
}
[[:lower:]][[:alnum:]_]* {
  cool_yylval.symbol = idtable.add_string(yytext);
  return OBJECTID;
}

 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for 
  *  \n \t \b \f, the result is c.
  *
  */
\" {
  BEGIN(str_literal);
  string_buf_ptr = string_buf;
}
<str_literal>{
  \n {
    assign_err_msg(ERR_STR_UNTERMINATED);
    curr_lineno++;
    BEGIN(INITIAL);
    return ERROR; 
  }
  \0 {
    assign_err_msg(ERR_STR_HAS_NULL);
    consume_invalid_str(curr_lineno);
    BEGIN(INITIAL);
    return ERROR; 
  }
  <<EOF>> {
    assign_err_msg(ERR_STR_HAS_EOF);
    BEGIN(INITIAL);
    return ERROR; 
  }
  \\b { *(string_buf_ptr++) = '\b'; }
  \\t { *(string_buf_ptr++) = '\t'; }
  \\n { *(string_buf_ptr++) = '\n'; }
  \\f { *(string_buf_ptr++) = '\f'; }
  \\[[:alnum:]] { *(string_buf_ptr++) = yytext[1]; }
  \\\n {
    *(string_buf_ptr++) = '\n';
    curr_lineno++;
  }
  [^\\\n\"]* {
    char* yptr = yytext;
    while (*yptr && string_buf_ptr != string_buf_end) {
      *(string_buf_ptr++) = *(yptr++);
    }
    if (*yptr) {
      assign_err_msg(ERR_STR_TOO_LONG);
      consume_invalid_str(curr_lineno);
      BEGIN(INITIAL);
      return ERROR; 
    }
  }
  \" {
    *string_buf_ptr = '\0';
    cool_yylval.symbol = stringtable.add_string(string_buf);
    BEGIN(INITIAL);
    return STR_CONST;
  }
}

 /*
  *  Inline/Nested comments
  */
-- {
  BEGIN(inline_comment);
}
\(\* {
  nest_comment_level++;
  BEGIN(comment);
}
\*\) {
  assign_err_msg(ERR_CMT_INVALID_CLOSE);
  return ERROR;
}
<inline_comment>{
  \n {
    curr_lineno++;
    BEGIN(INITIAL);
  }
  .* { }
}
<comment>{
  /* eat up anything not "*" or "*" not followed by ")" */
  [^\*\n]* { }
  \*[^*\)\n]* { }
  <<EOF>> {
    assign_err_msg(ERR_CMT_HAS_EOF);
    BEGIN(INITIAL);
    return ERROR;
  }
  \n { curr_lineno++; }
  \(\* {
    nest_comment_level++;
  }
  \*\) {
    nest_comment_level--;
    if (nest_comment_level == 0) {
      BEGIN(INITIAL);
    }
  }
}

 /* General rules */
([[:space:]]{-}[\n])+ { }
\n { curr_lineno++; }
. {
  assign_err_msg(yytext);
  return ERROR;
}

%%
void consume_invalid_str(int &lineno) {
  for (char c = yyinput(); c != '\n' && c != '"'; c = yyinput()) {
    if (c == '\n') {
      ++lineno;
    }
  }
}

void assign_err_msg(char* msg) {
  Symbol ptr = stringtable.add_string(msg);
  cool_yylval.error_msg = ptr->get_string();
}
