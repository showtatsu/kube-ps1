#!/usr/bin/env fish

# Kubernetes prompt helper for bash/zsh/fish
# Displays current context and namespace

# Copyright 2026 Jon Mosco
#
#  Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Debug
# $fish trace

if not set -q KUBE_PS1_BINARY
  set -g KUBE_PS1_BINARY kubectl
end

if not set -q KUBE_PS1_SYMBOL_ENABLE
  set -g KUBE_PS1_SYMBOL_ENABLE true
end

if not set -q KUBE_PS1_SYMBOL_PADDING
  set -g KUBE_PS1_SYMBOL_PADDING false
end

if not set -q KUBE_PS1_SYMBOL_USE_IMG
  set -g KUBE_PS1_SYMBOL_USE_IMG false
end

if not set -q KUBE_PS1_SYMBOL_OC_IMG
  set -g KUBE_PS1_SYMBOL_OC_IMG false
end

if not set -q KUBE_PS1_NS_ENABLE
  set -g KUBE_PS1_NS_ENABLE true
end

if not set -q KUBE_PS1_CONTEXT_ENABLE
  set -g KUBE_PS1_CONTEXT_ENABLE true
end

if not set -q KUBE_PS1_PREFIX
  set -g KUBE_PS1_PREFIX "("
end

if not set -q KUBE_PS1_SEPARATOR
  set -g KUBE_PS1_SEPARATOR "|"
end

if not set -q KUBE_PS1_DIVIDER
  set -g KUBE_PS1_DIVIDER ":"
end

if not set -q KUBE_PS1_SUFFIX
  set -g KUBE_PS1_SUFFIX ")"
end

if not set -q KUBE_PS1_SYMBOL_IMG
  set -g KUBE_PS1_SYMBOL_IMG "☸️"
end

if not set -q KUBE_PS1_CONTEXT
  set -g KUBE_PS1_CONTEXT "N/A"
end

if not set -q KUBE_PS1_NAMESPACE
  set -g KUBE_PS1_NAMESPACE "N/A"
end

if not set -q KUBE_PS1_ENABLED
  set -g KUBE_PS1_ENABLED on
end

set -g _KUBE_PS1_DISABLE_PATH $HOME/.kube/kube-ps1/disabled
if test -f "$_KUBE_PS1_DISABLE_PATH"
  set -g KUBE_PS1_ENABLED off
end

set -g _KUBE_PS1_KUBECONFIG_CACHE "$KUBECONFIG"
set -g _KUBE_PS1_LAST_TIME 0
set -g _KUBE_PS1_CFGFILES_READ_CACHE ""

function _kube_ps1_binary_check
    command -q $argv[1]
end

function _kube_ps1_split_config
    string split ":" $argv
end

function _kube_ps1_file_newer_than
    set -l mtime
    set -l file $argv[1]
    set -l check_time $argv[2]

    # file modification time options from kube-ps1
    if stat -c "%s" /dev/null >/dev/null 2>&1
        # GNU stat
        set mtime (stat -L -c %Y "$file")
    else
        # BSD stat
        set mtime (stat -L -f %m "$file")
    end

    test "$mtime" -gt "$check_time"
end

function _kube_ps1_prompt_update
    set -l return_code $status

  test "$KUBE_PS1_ENABLED" = "off"; and return $return_code

  if not _kube_ps1_binary_check "$KUBE_PS1_BINARY"
      # No ability to fetch context/namespace; display N/A.
      set -g KUBE_PS1_CONTEXT "BINARY-N/A"
      set -g KUBE_PS1_NAMESPACE "N/A"
      return $return_code
  end

  if test "$KUBECONFIG" != "$_KUBE_PS1_KUBECONFIG_CACHE"
      # User changed KUBECONFIG; unconditionally refetch.
      set -g _KUBE_PS1_KUBECONFIG_CACHE "$KUBECONFIG"
      _kube_ps1_get_ctx_ns
      return $return_code
  end

  set -l conf
  set -l config_file_cache

  # kubectl will read the environment variable $KUBECONFIG
  # otherwise set it to ~/.kube/config
  set -l kubeconfig "$KUBECONFIG"
  if test -z "$kubeconfig"
      set kubeconfig "$HOME/.kube/config"
  end

  for conf in (_kube_ps1_split_config "$kubeconfig")
      test -r "$conf"; or continue
      set -a config_file_cache "$conf"
      if _kube_ps1_file_newer_than "$conf" "$_KUBE_PS1_LAST_TIME"
          _kube_ps1_get_ctx_ns
          return $return_code
      end
  end

  if test "$config_file_cache" != "$_KUBE_PS1_CFGFILES_READ_CACHE"
      _kube_ps1_get_ctx_ns
      return $return_code
  end

  return $return_code
end

function _kube_ps1_get_context
  if test "$KUBE_PS1_CONTEXT_ENABLE" = true
      set -g KUBE_PS1_CONTEXT ($KUBE_PS1_BINARY config current-context 2>/dev/null)

      if test -z "$KUBE_PS1_CONTEXT"
          set -g KUBE_PS1_CONTEXT "N/A"
      end
  end
end

function _kube_ps1_get_ns
    if test "$KUBE_PS1_NS_ENABLE" = true
        set -g KUBE_PS1_NAMESPACE ($KUBE_PS1_BINARY config view --minify --output 'jsonpath={..namespace}' 2>/dev/null)

        if test -z "$KUBE_PS1_NAMESPACE"
            set -g KUBE_PS1_NAMESPACE "N/A"
        end
    end
end

function _kube_ps1_get_ctx_ns
  # Set the command time
  set -g _KUBE_PS1_LAST_TIME (date +%s)

  # Cache which cfgfiles we can read in case they change.
  set -l conf
  set -g _KUBE_PS1_CFGFILES_READ_CACHE ""

  set -l kubeconfig "$KUBECONFIG"
  if test -z "$kubeconfig"
      set kubeconfig "$HOME/.kube/config"
  end

  for conf in (_kube_ps1_split_config "$kubeconfig")
      if test -r "$conf"
          set -a _KUBE_PS1_CFGFILES_READ_CACHE "$conf"
      end
  end

  _kube_ps1_get_context
  _kube_ps1_get_ns
end

function _kube_ps1_symbol
  test "$KUBE_PS1_SYMBOL_ENABLE" = false; and return

  set -l KUBE_PS1_SYMBOL \u2638

  if test "$KUBE_PS1_SYMBOL_USE_IMG" = true
      set KUBE_PS1_SYMBOL "$KUBE_PS1_SYMBOL_IMG"
  end

  # OpenShift glyph
  # NOTE: this requires a patched "Nerd" font to work
  # https://www.nerdfonts.com/
  if test "$KUBE_PS1_SYMBOL_OC_IMG" = true
      set KUBE_PS1_SYMBOL \ue7b7
  end

  if test "$KUBE_PS1_SYMBOL_PADDING" = true
      echo "$KUBE_PS1_SYMBOL "
  else
      echo "$KUBE_PS1_SYMBOL"
  end
end

function _kubeon_usage
    echo "Toggle kube-ps1 prompt on"
    echo
    echo "Usage: kubeon [-g | --global] [-h | --help]"
    echo
    echo "With no arguments, turn on kube-ps1 status for this shell instance (default)."
    echo
    echo "  -g --global  turn on kube-ps1 status globally"
    echo "  -h --help    print this message"
end

function _kubeoff_usage
    echo "Toggle kube-ps1 prompt off"
    echo
    echo "Usage: kubeoff [-g | --global] [-h | --help]"
    echo
    echo "With no arguments, turn off kube-ps1 status for this shell instance (default)."
    echo
    echo "  -g --global turn off kube-ps1 status globally"
    echo "  -h --help   print this message"
end

function kubeon
    argparse h/help g/global -- $argv
    or return

    if set -ql _flag_help
        _kubeon_usage
        return 0
    end

    if set -ql _flag_global
        rm -f -- "$_KUBE_PS1_DISABLE_PATH"
    end

    set -g KUBE_PS1_ENABLED on
end

function kubeoff
    argparse h/help g/global -- $argv
    or return

    if set -ql _flag_help
        _kubeoff_usage
        return 0
    end

    if set -ql _flag_global
        mkdir -p -- (dirname "$_KUBE_PS1_DISABLE_PATH")
        touch -- "$_KUBE_PS1_DISABLE_PATH"
    end

    set -g KUBE_PS1_ENABLED off
end

# Build our prompt
function kube_ps1
    _kube_ps1_prompt_update

    test "$KUBE_PS1_ENABLED" = "off"; and return

    echo -n "$KUBE_PS1_PREFIX"(_kube_ps1_symbol)"$KUBE_PS1_SEPARATOR$KUBE_PS1_CONTEXT$KUBE_PS1_DIVIDER$KUBE_PS1_NAMESPACE$KUBE_PS1_SUFFIX"
end

