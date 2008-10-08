"=============================================================================
" File: pitconfig.vim
" Author: Yasuhiro Matsumoto <mattn.jp@gmail.com>
" Last Change: Wed, 08 Oct 2008
" Version: 0.1
" Usage:
"   :PitReload
"     reload pit config named as g:pitconfig_default
"   :PitLoad profile
"     load pit config named as 'profile'
"   :PitSave
"     save current variables to pit config which named as g:pitconfig_default
"   :PitSave profile
"     save current variables to pit config which named as 'profile'
"   :PitAdd varname
"     add variable to current pit config.
"
" Tips:
"   you can get pit config as Dictionary like following.
"
"   :echo PitGet('vimrc')['my_vim_config']

if &cp || (exists('g:loaded_pitconfig') && g:loaded_pitconfig)
  finish
endif
"let g:loaded_pitconfig = 1
"
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

let s:Pit = {}

function! PitGet(profile)
  let l:ret = {}
"perl: get pit config as JSON string {{{
perl <<__END__
{
  my $json = JSON::Syck::Dump(pit_get(''.VIM::Eval('a:profile')));
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

function! s:Pit:Load(profile)
"perl: load pit config to global scope {{{
perl <<__END__
{
  my $config = pit_get(''.VIM::Eval('a:profile'));
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

function! s:Pit:Add(varname)
  let l:profile = g:pitconfig_default
"perl: load pit config to global scope {{{
perl <<__END__
{
  local $JSON::Syck::SingleQuote = 1;
  my $profile = ''.VIM::Eval('l:profile');
  my $varname = ''.VIM::Eval('a:varname');
  my $config = pit_get($profile);
  my $vals = {};
  $config->{$varname} = '';
  for my $key (keys %$config) {
    VIM::DoCommand("let l:type = type(g:$key)");
    my $type = VIM::Eval('l:type');
    if ($type eq 3 || $type eq 4) {
      VIM::DoCommand("let l:val = string(g:$key)");
      my $val = VIM::Eval('l:val');
      $vals->{$key} = JSON::Syck::Load($val);
      VIM::DoCommand("silent! unlet l:val");
    } else {
      $vals->{$key} = VIM::Eval("g:$key");
    }
  }
  Config::Pit::set($profile, data => $vals);
  undef $config;
}
__END__
"}}}
endfunction

function! s:Pit:Save(...)
  let l:profile = g:pitconfig_default
  if a:0 == 1 && len(a:1)
    let l:profile = a:1
  endif
"perl: load pit config to global scope {{{
perl <<__END__
{
  local $JSON::Syck::SingleQuote = 1;
  my $profile = ''.VIM::Eval('l:profile');
  my $config = pit_get($profile);
  my $vals = {};
  for my $key (keys %$config) {
    VIM::DoCommand("let l:type = type(g:$key)");
    my $type = VIM::Eval('l:type');
    if ($type eq 3 || $type eq 4) {
      VIM::DoCommand("let l:val = string(g:$key)");
      my $val = VIM::Eval('l:val');
      $vals->{$key} = JSON::Syck::Load($val);
      VIM::DoCommand("silent! unlet l:val");
    } else {
      $vals->{$key} = VIM::Eval("g:$key");
    }
  }
  Config::Pit::set($profile, data => $vals);
  undef $config;
}
__END__
"}}}
endfunction

command! PitReload :call s:Pit:Load(g:pitconfig_default)
command! -nargs=1 PitLoad :call s:Pit:Load(<q-args>)
command! -nargs=* PitSave :call s:Pit:Save(<q-args>)
command! -nargs=1 PitAdd :call s:Pit:Add(<q-args>)

if g:pitconfig_autoload
  call s:Pit:Load(g:pitconfig_default)
endif
" vim:fdm=marker fdl=0 fdc=0 fdo+=jump,search:
" vim:fdt=substitute(getline(v\:foldstart),'\\(.\*\\){\\{3}','\\1',''):
