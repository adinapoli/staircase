" Copyright (C) 2012 Alfredo Di Napoli
"
" Permission is hereby granted, free of charge, to any person obtaining a copy
" of this software and associated documentation files (the "Software"), to deal
" in the Software without restriction, including without limitation the rights
" to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
" copies of the Software, and to permit persons to whom the Software is
" furnished to do so, subject to the following conditions:
"
" The above copyright notice and this permission notice shall be included in
" all copies or substantial portions of the Software.
"
" THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
" IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
" FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
" AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
" LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
" OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
" SOFTWARE.
"
if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin=1

if !has("python")
  finish
endif

" Default variables
if !exists("g:staircase_default_terminal")
  let g:staircase_default_terminal = "xterm"
endif

if !exists("g:staircase_buffer_location")
  let g:staircase_buffer_location = substitute(system("echo $HOME"), "\n", "", "g") . "/.staircase.buff"
endif


if !exists("g:staircase_use_sbt")
  let g:staircase_use_sbt = 1
endif

if !exists("b:staircase_send_ctrl_d")
  let b:staircase_send_ctrl_d = 0
endif


python << EOF
import vim
import os
import subprocess

def write_to_buffer():
  staircase_buff = vim.eval("g:staircase_buffer_location") 
  selected_lines = vim.eval("g:selected_text")
  selected_lines = discard_function_declaration(selected_lines)
  selected_lines = tag_if_multiline(selected_lines)

  f = open(staircase_buff, "w")

  for line in selected_lines:
    f.write(line)
    f.write(os.linesep)

  f.close()

def discard_function_declaration(lines):
  if contains_function_declaration(lines[0]):
    return lines[1:]
  return lines

def contains_function_declaration(line):
  return line.split(" ")[1] == "::"

def append_let_if_function(lines):

  #For now the dict will be created on-the-fly here.
  #Potentially very slow.

  not_prefixable_keywords = [
    "import", "data", "instance",
    "class", "type", "{-#"
  ]

  is_prefixable = lines[0].split(" ")[0] not in not_prefixable_keywords
  if is_prefixable:
    # We must also ident every other line that follows
    lines[0] = "let " + lines[0]
    for idx in range(1,len(lines)):
      lines[idx] = "    " + lines[idx]

  return lines

def line_starts_with(line, keyword):
  return keyword == line.split(" ")[0]

def tag_if_multiline(lines):
  # Decide whether wrapping the line for multiline
  # pasting
  if len(lines) > 1 and not line_starts_with(lines[0], "import"):
    return [":paste"] + lines
  return lines

def staircase_eval_visual():
  write_to_buffer()
  send_buffer_to_tmux()

def send_buffer_to_tmux():
  staircase_buff = vim.eval("g:staircase_buffer_location")
  subprocess.call(["tmux", "load-buffer", staircase_buff ])
  subprocess.call(["tmux", "pasteb", "-t", "staircase"])

  send_ctrl_d = vim.eval("b:staircase_send_ctrl_d") 
  if int(send_ctrl_d) == 1:
    subprocess.call(["tmux", "send-keys", "-t", "staircase", "C-D"])

def staircase_show_type_under_the_cursor():
  function_name = vim.eval("@z")
  write_to_buffer_raw(":type " + function_name)
  send_buffer_to_tmux()

def staircase_send_to_ghci():
  expr = vim.eval("cmd")
  write_to_buffer_raw(expr)
  send_buffer_to_tmux()

def write_to_buffer_raw(content):
  """
  Same of write_buffer, except that
  write @content without checking it.
  """
  staircase_buff = vim.eval("g:staircase_buffer_location") 
  f = open(staircase_buff, "w")

  f.write(content)
  f.write(os.linesep)

  f.close()

def staircase_kill():
  subprocess.call(["tmux", "kill-session", "-t", "staircase"])

EOF

"Connect to repl
fun! StaircaseConnect()

  " Allow nested tmux sessions.
  let $TMUX=""

  if StaircaseSessionExists()
    "Attach to an already running session
    echo "Connecting to an already running staircase session..."

    if (g:staircase_default_terminal == "urxvt")
      call system(g:staircase_default_terminal ." -e -sh -c \"tmux attach-session -t staircase\" &")
    else
      call system(g:staircase_default_terminal ." -e \"tmux attach-session -t staircase\" &")
    endif

    echo "Connected."

  else

    "Change the staircase owner to be this one
    let g:staircase_owner = getpid()
    echo "Starting a new staircase session..."
    let cmd = g:staircase_default_terminal

    if (g:staircase_default_terminal == "urxvt")
      let cmd .= " -e sh -c \"tmux new-session -s staircase "
    else
      let cmd .= " -e \"tmux new-session -s staircase "
    endif

    if(g:staircase_use_sbt)
      let cmd .= "'sbt console'\" &"
    else
      let cmd .= "'scala'\" &"
    endif

    call system(cmd)

  endif
endfun

fun! StaircaseSessionExists()
  let w:sessions = system("tmux list-sessions 2>&1 | grep staircase")
  if (w:sessions != "")
      return 1
  else
    return 0
  endif
endfun

fun! StaircaseEvalBuffer()

  let b:buffer_name = expand("%:p")
  let b:use_cmd = ":load ". b:buffer_name .""
  call system("echo \"". escape(b:use_cmd,"\"") ."\" > ". g:staircase_buffer_location)
  if StaircaseSessionExists()
    call system("tmux load-buffer ". g:staircase_buffer_location ."; tmux pasteb -t staircase")
  endif
endfun

function! s:NumSort(a, b)
    return a:a>a:b ? 1 : a:a==a:b ? 0 : -1
endfunction

function! s:GetVisualSelection()
  let [lnum1, col1] = getpos("'<")[1:2]
  let [lnum2, col2] = getpos("'>")[1:2]
  let lines = getline(lnum1, lnum2)
  return lines
endfunction

fun! StaircaseEvalVisual() range
  if StaircaseSessionExists()
    let g:selected_text = s:GetVisualSelection()

    if len(g:selected_text) > 1
      let b:staircase_send_ctrl_d = 1
    endif

    python staircase_eval_visual()
    let b:staircase_send_ctrl_d = 0
  endif
endfun

fun! StaircaseShowTypeUnderTheCursor()
  if StaircaseSessionExists()
    normal! "zyw
    python staircase_show_type_under_the_cursor()
  endif
endfun

fun! StaircaseSendToGhci()
  if StaircaseSessionExists()
    call inputsave()
    let cmd = input('Expr?: ')
    call inputrestore()
    python staircase_send_to_ghci()
  endif
endfun

fun! StaircaseCloseSession()
  if StaircaseSessionExists()
    if g:staircase_owner == getpid()
      python staircase_kill()
    endif
  endif
endfun

"Mnemonic: staircase Connect
map <LocalLeader>sc :call StaircaseConnect()<RETURN>

"Mnemonic: staircase (Eval) Buffer
map <LocalLeader>sb :call StaircaseEvalBuffer()<RETURN>

"Mnemonic: staircase (Eval) Visual (Selection)
map <LocalLeader>sv :call StaircaseEvalVisual()<RETURN>

"Mnemonic: staircase (Show) Type
map <LocalLeader>st :call StaircaseShowTypeUnderTheCursor()<RETURN>

"Mnemonic: staircase Send
map <LocalLeader>ss :call StaircaseSendToGhci()<RETURN>

"Kill staircase before exiting Vim
autocmd VimLeavePre * call StaircaseCloseSession()

" vim:sw=2
