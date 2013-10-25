function! taskwarrior#list(...) abort
    let pos = getpos('.')
    setlocal modifiable
    setlocal nowrap
    %delete
    if !exists('b:filter')
        let b:filter = ''
    endif
    if !exists('b:report')
        let b:report = 'list'
    endif
    if a:0 == 1
        if index(['active', 'all', 'block', 'completed', 'list', 'long', 'ls', 'minimal', 'newest', 'next', 'oldest', 'overdue', 'ready', 'recurring', 'unblocked', 'waiting'], a:1) != -1
            let b:filter = ''
            let b:report = a:1
        else
            let b:filter = a:1
            let b:report = 'list'
        endif
    elseif a:0 == 2
        let b:filter = a:1
        let b:report = a:2
    endif

    let b:task_report_columns = split(substitute(substitute(system("task _get -- rc.report.".b:report.".columns"), '*\|\n', '', 'g'), '\.', '_', 'g'), ',')
    let b:task_report_labels = split(substitute(system("task _get -- rc.report.".b:report.".labels"), '*\|\n', '', 'g'), ',')
    let line1 = join(b:task_report_labels, ' ')
    let line2 = substitute(line1, '\S', '-', 'g')
    call append(0, split((system("task ".b:filter." ".b:report)), '\n')[:-3])
    if len(getline(1)) == 0
        call append(line('$')-1, [line1, line2])
    endif
    let b:task_columns = [0]
    for col in range(len(getline(1))-1)
        if getline(1)[col] == " " && getline(1)[col+1] != " "
            let b:task_columns += [col+1]
        endif
    endfor
    setlocal filetype=taskwarrior
    setlocal buftype=nofile
    setlocal nomodifiable
    nnoremap <buffer> A :call taskwarrior#annotate('add')<CR>
    nnoremap <buffer> D :call taskwarrior#delete()<CR>
    nnoremap <buffer> a :call taskwarrior#system_call('', 'add', taskwarrior#get_args(), 'interactive')<CR>
    nnoremap <buffer> d :call taskwarrior#set_done()<CR>
    nnoremap <buffer> <CR> :call taskwarrior#info(taskwarrior#get_uuid().' info')<CR>
    nnoremap <buffer> m :call taskwarrior#system_call(taskwarrior#get_id(), 'modify', taskwarrior#get_args(), 'interactive')<CR>
    nnoremap <buffer> q :call taskwarrior#quit()<CR>
    nnoremap <buffer> r :call taskwarrior#clear_completed()<CR>
    nnoremap <buffer> u :call taskwarrior#undo()<CR>
    nnoremap <buffer> x :call taskwarrior#annotate('del')<CR>
    nnoremap <buffer> s :call taskwarrior#sync('sync')<CR>

    call setpos('.', pos)

endfunction

function! taskwarrior#init(...)
    if !executable('task')
       echoerr "This plugin depends on taskwarrior(http://taskwarrior.org)."
    endif
    if exists('g:task_view')
        execute g:task_view.'buffer'
    else
        execute 'edit task_list'
        let g:task_view = bufnr('%')
        setlocal noswapfile
    endif
    if a:0 == 0
        call taskwarrior#list()
    elseif len(split(a:1, ' ')) == 1
        call taskwarrior#list(a:1)
    else
        call taskwarrior#list(join(split(a:1, ' ')[0:-2],' '), split(a:1, ' ')[-1])
    endif

endfunction

function! taskwarrior#quit()
    silent! execute g:task_view.'bd!'
    unlet g:task_view
endfunction

function! taskwarrior#delete()
    execute "!task ".taskwarrior#get_uuid()." delete"
    call taskwarrior#list()
endfunction

function! taskwarrior#annotate(op)
    let annotation = input("annotation:")
    if a:op == 'add'
        call taskwarrior#system_call(taskwarrior#get_uuid(), ' annotate ', annotation, 'silent')
    else
        call taskwarrior#system_call(taskwarrior#get_uuid(), ' denotate ', annotation, 'silent')
    endif
endfunction

function! taskwarrior#set_done()
    if getline('.')[b:task_columns[1]:b:task_columns[2]-2] =~ 'Completed'
        return
    endif
    call taskwarrior#system_call(taskwarrior#get_uuid(), ' done', '', 'silent')
endfunction

function! taskwarrior#get_args()
    let due         = input("due:")
    let project     = input("project:")
    let priority    = input("priority:")
    let description = input("description:")
    let tag         = substitute(input("tags:"), ' ', ',', 'g')
    let depends     = substitute(input("depends:"), ' ', ',', 'g')
    return " due:".due." project:".project." priority:".priority." depends:".depends." tag:".tag." ".description
endfunction

function! taskwarrior#get_id()
    return matchstr(getline('.'), '^\s*\zs\d\+')." "
endfunction

function! taskwarrior#system_call(filter, command, args, mode)
    if a:mode == 'silent'
        call system("task ".a:filter.a:command.a:args)
    else
        echo system("task ".a:filter.a:command.a:args)
    endif
    call taskwarrior#list()
endfunction

function! taskwarrior#get_uuid()
    if index(b:task_report_columns, 'uuid') == -1
        return taskwarrior#get_id()
    endif
    return matchstr(getline('.'), '[0-9a-f]\{8}\(-[0-9a-f]\{4}\)\{3}-[0-9a-f]\{12}')
endfunction

function! taskwarrior#undo()
    if has("gui_running")
        if executable('xterm')
            silent !xterm -e "task undo"
        endif
    else
        !task undo
    endif
    call taskwarrior#list()
endfunction

function! taskwarrior#info(command)
    for line in split(system("task ".a:command), '\n')
        echo line
    endfor
endfunction

function! taskwarrior#clear_completed()
    !task status:completed delete
    call taskwarrior#list()
endfunction

"deprecated functions push, pull, merge
function! taskwarrior#remote(action)
    let uri = input("remote uri:")
    execute '!task '.a:action.' '.uri
    if exists('g:task_view')
        call taskwarrior#list()
    endif
endfunction

function! taskwarrior#sync(action)
    execute '!task '.a:action.' '
    if exists('g:task_view')
        call taskwarrior#list()
    endif
endfunction
" vim:ts=4:sw=4:tw=78:ft=vim:fdm=indent
