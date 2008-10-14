"=============================================================================
" File: pitconfig.vim
" Author: Yasuhiro Matsumoto <mattn.jp@gmail.com>
" Last Change: Wed, 08 Oct 2008
" Version: 0.1
" Usage:
"   :PitReload
"     reload pit config named as g:pitconfig_default
"
"   :PitLoad profile
"     load pit config named as 'profile'
"
"   :PitShow
"     show current pit config named as g:pitconfig_default
"   :PitShow profile
"     show current pit config named as 'profile'
"
"   :PitEdit
"     open pit config file with text editor asigned $EDITOR
"
"   :PitSave
"     save current variables to pit config which named as g:pitconfig_default
"   :PitSave profile
"     save current variables to pit config which named as 'profile'
"
"   :PitAdd varname
"     add variable to current pit config.
"
"   :PitDel varname
"     delete variable from current pit config.
"
" Tips:
"   you can get pit config as Dictionary like following.
"
"     :echo PitGet('vimrc')['my_vim_config']
"     :echo PitGet()['my_vim_config']
"
"   you can set pit config like following.
"
"     :call PitSet({ 'foo': 'bar' })
"     :call PitSet({ 'foo': 'bar' }, 'myprofile')
"
" GetLatestVimScripts: 2404 1 :AutoInstall: pitconfig.vim

if &cp || (exists('g:loaded_pitconfig') && g:loaded_pitconfig)
  finish
endif
let g:loaded_pitconfig = 1

if !exists('g:pitconfig_default')
  let g:pitconfig_default = 'vimrc'
endif
if !exists('g:pitconfig_autoload')
  let g:pitconfig_autoload = 1
endif

if !has('perl')
  finish
endif

"perl: use modules {{{
:perl << __END__
use JSON::Syck;
use Config::Pit;
__END__
"}}}

function! PitGet(...)
  if a:0 == 0
    let l:profname = g:pitconfig_default
  elseif a:0 == 1 && len(a:1)
    let l:profname = a:1
  else
    throw "too many arguments"
  endif
  let l:ret = {}
"perl: get pit config as JSON string {{{
perl <<__END__
{
  my $json = JSON::Syck::Dump(pit_get(''.VIM::Eval('l:profname')));
  VIM::DoCommand("let l:ret = $json");
  undef $json;
}
__END__
" }}}
  if !exists('l:ret')
    let ret = {}
  endif
  return l:ret
endfunction

function! PitSet(...)
  if a:0 == 1 && len(a:1)
    let l:data = string(a:1)
    let l:profname = g:pitconfig_default
  elseif a:0 == 2 && len(a:1) && len(a:2)
    let l:data = string(a:1)
    let l:profname = a:2
  else
    throw "too many or few arguments"
  endif
  let l:ret = {}
"perl: save to pit config {{{
perl <<__END__
{
  local $JSON::Syck::SingleQuote = 1;
  my $profname = ''.VIM::Eval('l:profname');
  my $data = VIM::Eval('l:data');
  Config::Pit::set($profname, data => JSON::Syck::Load($data));
  undef $data;
  undef $profname;
}
__END__
"}}}
endfunction

function! s:PitLoad(profname)
"perl: load pit config to global scope {{{
perl <<__END__
{
  my $config = pit_get(''.VIM::Eval('a:profname'));
  for my $key (keys %$config) {
    my $val = $config->{$key};
    if (!ref($val) || ref($val) eq 'SCALAR') {
      VIM::DoCommand("silent! unlet g:$key|let g:$key = '$val'");
    } else {
      $val = JSON::Syck::Dump($val);
      VIM::DoCommand("silent! unlet g:$key|let g:$key = $val");
    }
  }
  undef $config;
}
__END__
"}}}
endfunction

function! s:PitAdd(...)
  let l:profname = g:pitconfig_default
"perl: add variable to pit config {{{
perl <<__END__
{
  local $JSON::Syck::SingleQuote = 1;
  my $profname = ''.VIM::Eval('l:profname');
  my $varcount = ''.VIM::Eval('a:0');
  my $config = pit_get($profname);
  my $data = {};
  for (1..$varcount) {
    my $varname = ''.VIM::Eval("a:$_");
    $varname =~ s!^[gsl]:!! ;
    $config->{$varname} = '';
  }
  for my $key (keys %$config) {
    VIM::DoCommand("let l:type = type(g:$key)");
    my $type = VIM::Eval('l:type');
    if ($type eq 3 || $type eq 4) {
      VIM::DoCommand("let l:val = string(g:$key)");
      my $val = VIM::Eval('l:val');
      $data->{$key} = JSON::Syck::Load($val);
      VIM::DoCommand("silent! unlet l:val");
    } else {
      $data->{$key} = VIM::Eval("g:$key");
    }
  }
  Config::Pit::set($profname, data => $data);
  undef $data;
  undef $config;
  undef $varname;
  undef $profname;
}
__END__
"}}}
endfunction

function! s:PitDel(...)
  let l:profname = g:pitconfig_default
"perl: delete variable from pit config {{{
perl <<__END__
{
  local $JSON::Syck::SingleQuote = 1;
  my $profname = ''.VIM::Eval('l:profname');
  my $config = pit_get($profname);
  my $data = {};
  my $varcount = ''.VIM::Eval('a:0');
  my @varnames;
  for (1..$varcount) {
    my $varname = ''.VIM::Eval("a:$_");
    $varname =~ s!^[gsl]:!! ;
    push @varnames, $varname;
  }
  for my $key (keys %$config) {
    next if grep {$_ eq $key} @varnames;
    VIM::DoCommand("let l:type = type(g:$key)");
    my $type = VIM::Eval('l:type');
    if ($type eq 3 || $type eq 4) {
      VIM::DoCommand("let l:val = string(g:$key)");
      my $val = VIM::Eval('l:val');
      $data->{$key} = JSON::Syck::Load($val);
      VIM::DoCommand("silent! unlet l:val");
    } else {
      $data->{$key} = VIM::Eval("g:$key");
    }
  }
  Config::Pit::set($profname, data => $data);
  undef $data;
  undef $config;
  undef $varname;
  undef $profname;
}
__END__
"}}}
endfunction

function! s:PitShow(...)
  let l:profname = g:pitconfig_default
  if a:0 == 1 && len(a:1)
    let l:profname = a:1
  endif
  let l:config = PitGet(l:profname)
  echohl Title | echo l:profname | echohl None
  for l:key in keys(l:config)
    echohl LineNr | echo l:key | echohl None | echon ":"
    echo " " l:config[key]
  endfor
  silent! unlet l:config
endfunction

function! s:PitEdit(...)
  let l:profname = g:pitconfig_default
  if a:0 == 1 && len(a:1)
    let l:profname = a:1
  endif
  if len($EDITOR) == 0
    let $EDITOR = v:progname
  endif
  if executable('ppit')
    exec '!ppit set ' l:profname
  elseif executable('pit')
    exec '!pit set ' l:profname
  endif
endfunction

function! s:PitSave(...)
  let l:profname = g:pitconfig_default
  if a:0 == 1 && len(a:1)
    let l:profname = a:1
  endif
"perl: save to pit config {{{
perl <<__END__
{
  local $JSON::Syck::SingleQuote = 1;
  my $profname = ''.VIM::Eval('l:profname');
  my $config = pit_get($profname);
  my $data = {};
  for my $key (keys %$config) {
    VIM::DoCommand("let l:type = type(g:$key)");
    my $type = VIM::Eval('l:type');
    if ($type eq 3 || $type eq 4) {
      VIM::DoCommand("let l:val = string(g:$key)");
      my $val = VIM::Eval('l:val');
      $data->{$key} = JSON::Syck::Load($val);
      VIM::DoCommand("silent! unlet l:val");
    } else {
      $data->{$key} = VIM::Eval("g:$key");
    }
  }
  Config::Pit::set($profname, data => $data);
  undef $data;
  undef $config;
  undef $profname;
}
__END__
"}}}
endfunction

command! PitReload :call s:PitLoad(g:pitconfig_default)
command! -nargs=1 PitLoad :call s:PitLoad(<q-args>)
command! -nargs=* PitSave :call s:PitSave(<q-args>)
command! -nargs=* PitShow :call s:PitShow(<q-args>)
command! -nargs=* PitEdit :call s:PitEdit(<q-args>)
command! -nargs=+ -complete=var PitAdd :call s:PitAdd(<f-args>)
command! -nargs=+ -complete=var PitDel :call s:PitDel(<f-args>)

if g:pitconfig_autoload
  call s:PitLoad(g:pitconfig_default)
endif
" vim:fdm=marker fdl=0 fdc=0 fdo+=jump,search:
" vim:fdt=substitute(getline(v\:foldstart),'\\(.\*\\){\\{3}','\\1',''):
