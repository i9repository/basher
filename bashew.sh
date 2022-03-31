#!/usr/bin/env bash

# Marcelo Sena
# marcelosenaonline@hotmail.com
# i9repository

# BASHEW_AUTHOR_FULLNAME="Marcelo Sena"
# BASHEW_AUTHOR_USERNAME="i9repository"
# BASHEW_AUTHOR_EMAIL="marcelosenaonline@hotmail.com"

# se houver um arquivo 'version' na pasta deste script, ele terá prioridade para o número da versão
script_version="0.0.1"

readonly script_author="marcelosenaonline@hotmail.com"
readonly script_created="2022-03-30 23:00"

# run_as_root:
#    0 = não verifique nada
#    1 = o script DEVE ser executado como root
#   -1 = o script NÃO PODE ser executado como root
readonly run_as_root=-1

list_options() {
  echo -n "
#as linhas comentadas serão filtradas
flag|h|help|mostrar opções ajuda/uso
flag|q|quiet|sem saída
flag|v|verbose|mais informações de saída/debug
flag|f|force|não peça confirmação (sempre sim)
option|l|log_dir|diretório para arquivos de depuração|$HOME/log/$script_prefix
option|t|tmp_dir|diretório para arquivos temporários|/tmp/$script_prefix
option|n|name|nome do novo script ou projeto
param|1|action|ações disponíveis: script/project/init/update
" | grep -v '^#'
}

list_examples() {
  echo -n "
$script_basename script  : criar novo script (autônomo) (interativo)
$script_basename project : criar novo repositório de script bash (interativo)
$script_basename init    : inicialize este repositório como um novo projeto (quando gerado a partir do repositório de modelo 'bashew')
$script_basename update  : atualizar $script_basename para a versão mais recente (git pull)
" | grep -v '^$'
}

## Put your helper scripts here
get_author_data() {
  # $1 = nome proposto do script/project
  
  ## produzir dados padrão do autor
  guess_fullname="$(whoami)"
  guess_username="$guess_fullname"
  guess_email="$guess_fullname@$(hostname)"

  # se houver dados anteriores, use isso
  [[ -n ${BASHEW_AUTHOR_FULLNAME:-} ]] && guess_fullname="$BASHEW_AUTHOR_FULLNAME"
  [[ -n ${BASHEW_AUTHOR_EMAIL:-} ]] && guess_email="$BASHEW_AUTHOR_EMAIL"
  [[ -n ${BASHEW_AUTHOR_USERNAME:-} ]] && guess_username="$BASHEW_AUTHOR_USERNAME"

  # se houver dados de configuração do git, use isso
  # shellcheck disable=SC2154
  if [[ -n "$git_repo_root" ]]; then
    guess_fullname=$(git config user.name)
    guess_email=$(git config user.email)
    guess_username=$(git config remote.origin.url | cut -d: -f2)
    # git@github.com:pforret/bashew.git => pforret/bashew.git
    guess_username=$(dirname "$guess_username")
    # pforret/bashew.git => pforret
    guess_username=$(basename "$guess_username")
  fi
  
  if ((force)); then
    author_fullname="$guess_fullname"
    author_email="$guess_email"
    author_username="$guess_username"
    new_name="$1"
    clean_name=$(basename "$new_name" .sh)
    new_description="Este é o script $clean_name"
  else
    announce "1. primeiro precisamos das informações do autor"
    author_fullname=$(ask "Nome completo do autor     " "$guess_fullname")
    author_email=$(ask "E-mail do autor            " "$guess_email")
    author_username=$(ask "Usuário (github) do autor  " "$guess_username")
    export BASHEW_AUTHOR_FULLNAME="$author_fullname"
    export BASHEW_AUTHOR_EMAIL="$author_email"
    export BASHEW_AUTHOR_USERNAME="$author_username"

    announce "2. agora precisamos do caminho e nome deste novo script/repo"
    new_name=$(ask "Nome do script" "$1")

    announce "3. uma descrição do que o script faz"
    clean_name=$(basename "$new_name" .sh)
    new_description=$(ask "Descrição do script" "Este é o script $clean_name")
  fi
}

copy_and_replace() {
  local input="$1"
  local output="$2"

  if [[ ! -f "$input" ]]; then
    return 0
  fi
  awk \
    -v author_fullname="$author_fullname" \
    -v author_username="$author_username" \
    -v author_email="$author_email" \
    -v package_name="$clean_name" \
    -v package_description="$new_description" \
    -v meta_h="$execution_h" \
    -v meta_today="$execution_day" \
    -v meta_year="$execution_year" \
    -v bashew_version="$script_version" \
    '{
    gsub(/author_name/,author_fullname);
    gsub(/author_username/,author_username);
    gsub(/author@email.com/,author_email);
    gsub(/package_name/,package_name);
    gsub(/package_description/,package_description);
    gsub(/meta_h/,meta_h);
    gsub(/meta_today/,meta_today);
    gsub(/meta_year/,meta_year);
    gsub(/bashew_version/,bashew_version);
    print;
    }' \
    <"$input" \
    >"$output"
}

random_word() {
  (
    if aspell -v >/dev/null 2>&1; then
      aspell -d en dump master | aspell -l en expand
    elif [[ -f /usr/share/dict/words ]]; then
      # works on MacOS
      cat /usr/share/dict/words
    elif [[ -f /usr/dict/words ]]; then
      cat /usr/dict/words
    else
      printf 'zero,one,two,three,four,five,six,seven,eight,nine,ten,alfa,bravo,charlie,delta,echo,foxtrot,golf,hotel,india,juliet,kilo,lima,mike,november,oscar,papa,quebec,romeo,sierra,tango,uniform,victor,whiskey,xray,yankee,zulu%.0s' {1..3000} |
        tr ',' "\n"
    fi
  ) |
    awk 'length($1) > 2 && length($1) < 8 {print}' |
    grep -v "'" |
    grep -v " " |
    awk "NR == $RANDOM {print tolower(\$0)}"
}

delete_stuff() {
  if [[ -d "$1" ]]; then
    debug "Delete folder [$1]"
    rm -fr "$1"
  fi
  if [[ -f "$1" ]]; then
    debug "Delete file [$1]"
    rm "$1"
  fi
}

main() {
  debug "Programa : $script_basename $script_version"
  debug "Descrição: $script_modified"
  debug "Executado: $USER@$HOSTNAME"
  
  # adicionar as dependências do script aqui, como tar, wget, ffmpeg, rsync ...
  require_binary tput
  require_binary uname
  require_binary git
  local model="script"

  action=$(lower_case "$action")
  case $action in
  script | new)
    if [[ -n "${name:-}" ]] && [[ ! "$name" == " " ]]; then
      debug "Usando nome [$name]"
      get_author_data "$name"
    else
      random_name="$(random_word)_$(random_word).sh"
      debug "Usando nome [$random_name]"
      get_author_data "./$random_name"
    fi
    announce "Criando script $new_name ..."
    # shellcheck disable=SC2154
    copy_and_replace "$script_install_folder/template/$model.sh" "$new_name"
    chmod +x "$new_name"
    echo "$new_name"
    ;;

  project)
    if [[ -n "${name:-}" ]] && [[ ! "$name" == " " ]]; then
      get_author_data "$name"
    else
      random_name="$(random_word)_$(random_word)"
      get_author_data "./$random_name"
    fi
    if [[ ! -d "$new_name" ]]; then
      announce "Criando projeto $new_name ..."
      mkdir "$new_name"
      template_folder="$script_install_folder/template"
      ## primeiro todos os arquivos que podem mudar
      for file in "$template_folder"/*.md "$template_folder/LICENSE" "$template_folder"/.gitignore "$template_folder"/.env.example; do
        bfile=$(basename "$file")
        ((quiet)) || echo -n "$bfile "
        new_file="$new_name/$bfile"
        copy_and_replace "$file" "$new_file"
      done
      ((quiet)) || echo -n "$clean_name.sh "
      copy_and_replace "$template_folder/$model.sh" "$new_name/$clean_name.sh"
      chmod +x "$new_name/$clean_name.sh"
      ## agora arquivos CI/CD
      if [[ -f "$template_folder/bitbucket-pipelines.yml" ]]; then
        ((quiet)) || echo -n "bitbucket-pipelines "
        cp "$template_folder/bitbucket-pipelines.yml" "$new_name/"
      fi
      if [[ -d "$template_folder/.github" ]]; then
        ((quiet)) || echo -n ".github "
        cp -r "$template_folder/.github" "$new_name/.github"
      fi

      ((quiet)) || echo " "
      if confirm "Você quer executar 'git init' para o novo projeto?"; then
        (pushd "$new_name" && git init && git add . && popd || return) >/dev/null 2>&1
      fi
      success "Próxima Etapa: 'cd $new_name' e comece a escrever!"
    else
      alert "A pasta [$new_name] já existe, não pode fazer um novo projeto lá"
    fi
    ;;

  init)
    repo_name=$(basename "$script_install_folder")
    [[ "$repo_name" == "bashew" ]] && die "Você só pode executar o '$script_basename init' de um *novo* repositório, derivado do template bashew no Github."
    [[ ! -d ".git" ]] && die "Você só pode executar '$script_basename init' na raiz do seu repositório"
    [[ ! -d "template" ]] && die "A pasta 'template' parece estar ausente, você tem certeza de que este repositório foi clonado recentemente de pforret/bashew?"
    [[ ! -f "$script_install_folder/template/$model.sh" ]] && die "$model.sh não é um template válido"
    new_name="$repo_name.sh"
    get_author_data "./$new_name"
    announce "Criando script $new_name ..."
    # shellcheck disable=SC2154
    for file in template/*.md template/LICENSE template/.gitignore template/.gitignore; do
      bfile=$(basename "$file")
      ((quiet)) || echo -n "$bfile "
      new_file="./$bfile"
      rm -f "$new_file"
      copy_and_replace "$file" "$new_file"
    done
    copy_and_replace "$script_install_folder/template/$model.sh" "$new_name"
    chmod +x "$new_name"
    git add "$new_name"
    alt_dir=$(dirname "$new_name")
    alt_base=$(basename "$new_name" .sh)
    alt_name="$alt_dir/$alt_base"
    if [[ ! "$alt_name" == "$new_name" ]]; then
      # criar um "do_this" alias para "do_this.sh"
      ln -s "$new_name" "$alt_name"
      git add "$alt_name"
    fi
    announce "Agora limpando arquivos bashew desnecessários ..."
    delete_stuff template
    delete_stuff tests/disabled
    delete_stuff tests/test_bashew.sh
    delete_stuff tests/test_functions.sh
    delete_stuff assets
    delete_stuff .tmp
    delete_stuff log
    delete_stuff doc
    debug "Excluir script [bashew.sh] ..."
    (
      sleep 1
      rm -f bashew.sh bashew
    ) & # deletar após a conclusão do script
    success "script $new_name criado!"
    success "now do: ${col_ylw}git commit -a -m 'after bashew init' && git push${col_reset}"
    out "tip: install ${col_ylw}basher${col_reset} and ${col_ylw}pforret/setver${col_reset} para fácil gerenciamento de versão de script bash"
    ;;

  update)
    pushd "$script_install_folder" || die "Sem acesso à pasta [$script_install_folder]"
    git pull || die "Não é possível atualizar com git"
    # shellcheck disable=SC2164
    popd
    ;;

  check | env)
    ## deixe esta ação padrão, isso facilitará o teste do seu script
    #TIP: use «$script_prefix check» verificar se o script está pronto para ser executado e quais são os valores das opções/flags
    #TIP:> $script_prefix check
    #TIP: use «$script_prefix env» gerar arquivo .env de exemplo
    #TIP:> $script_prefix env > .env
    check_script_settings
    ;;

  \
    debug)
    out "print_with_out=yes"
    debug "print_with_log=yes"
    announce "print_with_announce=yes"
    success "print_with_success=yes"
    progress "print_with_progress=yes"
    echo ""
    alert "print_with_alert=yes"

    hash3=$(echo "1234567890" | hash 3)
    hash6=$(echo "1234567890" | hash)
    out "hash3=$hash3"
    out "hash6=$hash6"
    out "script_basename=$script_basename"
    out "script_author=$script_author"
    out "escape1 = $(escape "/forward/slash")"
    out "escape2 = $(escape '\backward\slash')"
    out "lowercase = $(lower_case 'AbCdEfGhIjKlMnÔû')"
    out "uppercase = $(upper_case 'AbCdEfGhIjKlMnÔû')"
    out "slugify   = $(slugify 'AbCdEfGhIjKlMnÔû')"
    # shellcheck disable=SC2015
    is_set "$force" && out "force=$force (true)" || out "force=$force (false)"
    ;;

  *)
    die "o parâmetro [$action] não reconhecido"
    ;;
  esac
}

#####################################################################
################# NÃO MODIFIQUE ABAIXO DESTA LINHA ##################
#####################################################################

# set strict mode -  via http://redsymbol.net/articles/unofficial-bash-strict-mode/
# removido -e porque dificultava [[ testes ]] básicos
set -uo pipefail
IFS=$'\n\t'
hash() {
  length=${1:-6}
  if [[ -n $(command -v md5sum) ]]; then
    # regular linux
    md5sum | cut -c1-"$length"
  else
    # macos
    md5 | cut -c1-"$length"
  fi
}

force=0
help=0
verbose=0
# habilitar verbose mesmo antes da análise de opções
[[ $# -gt 0 ]] && [[ $1 == "-v" ]] && verbose=1
quiet=0
# habilitar quiet mesmo antes da análise de opções
[[ $# -gt 0 ]] && [[ $1 == "-q" ]] && quiet=1

### stdout/stderr output
initialise_output() {
  [[ "${BASH_SOURCE[0]:-}" != "${0}" ]] && sourced=1 || sourced=0
  [[ -t 1 ]] && piped=0 || piped=1 # detect if output is piped
  if [[ $piped -eq 0 ]]; then
    col_reset="\033[0m"
    col_red="\033[1;31m"
    col_grn="\033[1;32m"
    col_ylw="\033[1;33m"
  else
    col_reset=""
    col_red=""
    col_grn=""
    col_ylw=""
  fi
  # detecta se o unicode é suportado
  [[ $(echo -e '\xe2\x82\xac') == '€' ]] && unicode=1 || unicode=0
  if [[ $unicode -gt 0 ]]; then
    char_succ="✅"
    char_fail="⛔"
    char_alrt="✴️"
    char_wait="⏳"
    info_icon="🌼"
    config_icon="🌱"
    clean_icon="🧽"
    require_icon="🔌"
  else
    char_succ="OK "
    char_fail="!! "
    char_alrt="?? "
    char_wait="..."
    info_icon="(i)"
    config_icon="[c]"
    clean_icon="[c]"
    require_icon="[r]"
  fi
  error_prefix="${col_red}>${col_reset}"
}

out() { ((quiet)) && true || printf '%b\n' "$*"; }
debug() { if ((verbose)); then out "${col_ylw}# $* ${col_reset}" >&2; else true; fi; }
die() {
  out "${col_red}${char_fail} $script_basename${col_reset} : $*" >&2
  tput bel
  safe_exit
}
alert() { out "${col_red}${char_alrt}${col_reset}: $*" >&2; }
success() { out "${col_grn}${char_succ}${col_reset}  $*"; }
announce() {
  out "${col_grn}${char_wait}${col_reset}  $*"
  sleep 1
}
progress() {
  ((quiet)) || (
    local screen_width
    screen_width=$(tput cols 2>/dev/null || echo 80)
    local rest_of_line
    rest_of_line=$((screen_width - 5))

    if flag_set ${piped:-0}; then
      out "$*" >&2
    else
      printf "... %-${rest_of_line}b\r" "$*                                             " >&2
    fi
  )
}

log_to_file() { [[ -n ${log_file:-} ]] && echo "$(date '+%H:%M:%S') | $*" >>"$log_file"; }

### processamento de strings
lower_case() { echo "$*" | tr '[:upper:]' '[:lower:]'; }
upper_case() { echo "$*" | tr '[:lower:]' '[:upper:]'; }
escape() { echo "$*" | sed 's/\//\\\//g'; }
is_set() { [[ "$1" -gt 0 ]]; }

slugify() {
  # slugify <input> <separator>
  # slugify "Jack, Jill & Clémence LTD"      => jack-jill-clemence-ltd
  # slugify "Jack, Jill & Clémence LTD" "_"  => jack_jill_clemence_ltd
  separator="${2:-}"
  [[ -z "$separator" ]] && separator="-"
  # shellcheck disable=SC2020
  echo "$1" |
    tr '[:upper:]' '[:lower:]' |
    tr 'àáâäæãåāçćčèéêëēėęîïííīįìłñńôöòóœøōõßśšûüùúūÿžźż' 'aaaaaaaaccceeeeeeeiiiiiiilnnoooooooosssuuuuuyzzz' |
    awk '{
          gsub(/[\[\]@#$%^&*;,.:()<>!?\/+=_]/," ",$0);
          gsub(/^  */,"",$0);
          gsub(/  *$/,"",$0);
          gsub(/  */,"-",$0);
          gsub(/[^a-z0-9\-]/,"");
          print;
          }' |
    sed "s/-/$separator/g"
}

title_case() {
  # title_case <input> <separator>
  # title_case "Jack, Jill & Clémence LTD"     => JackJillClemenceLtd
  # title_case "Jack, Jill & Clémence LTD" "_" => Jack_Jill_Clemence_Ltd
  separator="${2:-}"
  # shellcheck disable=SC2020
  echo "$1" |
    tr '[:upper:]' '[:lower:]' |
    tr 'àáâäæãåāçćčèéêëēėęîïííīįìłñńôöòóœøōõßśšûüùúūÿžźż' 'aaaaaaaaccceeeeeeeiiiiiiilnnoooooooosssuuuuuyzzz' |
    awk '{ gsub(/[\[\]@#$%^&*;,.:()<>!?\/+=_-]/," ",$0); print $0; }' |
    awk '{
          for (i=1; i<=NF; ++i) {
              $i = toupper(substr($i,1,1)) tolower(substr($i,2))
          };
          print $0;
          }' |
    sed "s/ /$separator/g" |
    cut -c1-50
}

### interactive
confirm() {
  # $1 = pergunta
  flag_set $force && return 0
  read -r -p "$1 [s/N] " -n 1
  echo " "
  [[ $REPLY =~ ^[Yy]$ ]]
}

ask() {
  # $1 = pergunta
  # $2 = valor padrão
  local ANSWER
  if [[ -n "${2:-}" ]]; then
    read -r -p "$1 ($2) > " ANSWER
  else
    read -r -p "$1      > " ANSWER
  fi
  [[ -n "$ANSWER" ]] && echo "$ANSWER" || echo "${2:-}"
}

trap "die \"ERROR \$? after \$SECONDS seconds \n\
\${error_prefix} last command : '\$BASH_COMMAND' \" \
\$(< \$script_install_path awk -v lineno=\$LINENO \
'NR == lineno {print \"\${error_prefix} from line \" lineno \" : \" \$0}')" INT TERM EXIT
# cf https://askubuntu.com/questions/513932/what-is-the-bash-command-variable-good-for

safe_exit() {
  [[ -n "${tmp_file:-}" ]] && [[ -f "$tmp_file" ]] && rm "$tmp_file"
  trap - INT TERM EXIT
  debug "$script_basename finalizado depois de $SECONDS segundos"
  exit 0
}

flag_set() { [[ "$1" -gt 0 ]]; }

show_usage() {
  out "Programa  : ${col_grn}$script_basename $script_version${col_reset} por ${col_ylw}$script_author${col_reset}"
  out "Atualizado: ${col_grn}$script_modified${col_reset}"
  out "Descrição : Criar scripts/projetos bash"
  echo -n "Uso: $script_basename"
  list_options |
    awk '
  BEGIN { FS="|"; OFS=" "; oneline="" ; fulltext="Flags, opções e parâmetros:"}
  $1 ~ /flag/  {
    fulltext = fulltext sprintf("\n    -%1s|--%-12s: [flag] %s [padrão: off]",$2,$3,$4) ;
    oneline  = oneline " [-" $2 "]"
    }
  $1 ~ /option/  {
    fulltext = fulltext sprintf("\n    -%1s|--%-12s: [opção] %s",$2,$3 " <?>",$4) ;
    if($5!=""){fulltext = fulltext "  [padrão: " $5 "]"; }
    oneline  = oneline " [-" $2 " <" $3 ">]"
    }
  $1 ~ /list/  {
    fulltext = fulltext sprintf("\n    -%1s|--%-12s: [list] %s (array)",$2,$3 " <?>",$4) ;
    fulltext = fulltext "  [padrão empty]";
    oneline  = oneline " [-" $2 " <" $3 ">]"
    }
  $1 ~ /secret/  {
    fulltext = fulltext sprintf("\n    -%1s|--%s <%s>: [secret] %s",$2,$3,"?",$4) ;
      oneline  = oneline " [-" $2 " <" $3 ">]"
    }
  $1 ~ /param/ {
    if($2 == "1"){
          fulltext = fulltext sprintf("\n    %-17s: [parâmetro] %s","<"$3">",$4);
          oneline  = oneline " <" $3 ">"
     }
     if($2 == "?"){
          fulltext = fulltext sprintf("\n    %-17s: [parameter] %s (optional)","<"$3">",$4);
          oneline  = oneline " <" $3 "?>"
     }
     if($2 == "n"){
          fulltext = fulltext sprintf("\n    %-17s: [parameters] %s (1 or more)","<"$3">",$4);
          oneline  = oneline " <" $3 " …>"
     }
    }
    END {print oneline; print fulltext}
  '
}

check_last_version() {
  (
    # shellcheck disable=SC2164
    pushd "$script_install_folder" &>/dev/null
    if [[ -d .git ]]; then
      local remote
      remote="$(git remote -v | grep fetch | awk 'NR == 1 {print $2}')"
      progress "Verifique a versão mais recente - $remote"
      git remote update &>/dev/null
      if [[ $(git rev-list --count "HEAD...HEAD@{upstream}" 2>/dev/null) -gt 0 ]]; then
        out "Há uma atualização mais recente deste script - execute <<$script_prefix update>> para atualizar"
      fi
    fi
    # shellcheck disable=SC2164
    popd &>/dev/null
  )
}

update_script_to_latest() {
  # executado em segundo plano para evitar problemas com a modificação de um script interpretado em execução
  (
    sleep 1
    cd "$script_install_folder" && git pull
  ) &
}

show_tips() {
  ((sourced)) && return 0
  # shellcheck disable=SC2016
  grep <"${BASH_SOURCE[0]}" -v '$0' |
    awk \
      -v green="$col_grn" \
      -v yellow="$col_ylw" \
      -v reset="$col_reset" \
      '
      /TIP: /  {$1=""; gsub(/«/,green); gsub(/»/,reset); print "*" $0}
      /TIP:> / {$1=""; print " " yellow $0 reset}
      ' |
    awk \
      -v script_basename="$script_basename" \
      -v script_prefix="$script_prefix" \
      '{
      gsub(/\$script_basename/,script_basename);
      gsub(/\$script_prefix/,script_prefix);
      print ;
      }'
}

check_script_settings() {
  if [[ -n $(filter_option_type flag) ]]; then
    local name
    out "## ${col_grn}flags boleano${col_reset}:"
    filter_option_type flag |
      while read -r name; do
        if ((piped)); then
          eval "echo \"$name=\$${name:-}\""
        else
          eval "echo -n \"$name=\$${name:-}  \""
        fi
      done
    out " "
    out " "
  fi

  if [[ -n $(filter_option_type option) ]]; then
    out "## ${col_grn}opção padrão${col_reset}:"
    filter_option_type option |
      while read -r name; do
        if ((piped)); then
          eval "echo \"$name=\$${name:-}\""
        else
          eval "echo -n \"$name=\$${name:-}  \""
        fi
      done
    out " "
    out " "
  fi

  if [[ -n $(filter_option_type list) ]]; then
    out "## ${col_grn}list options${col_reset}:"
    filter_option_type list |
      while read -r name; do
        if ((piped)); then
          eval "echo \"$name=(\${${name}[@]})\""
        else
          eval "echo -n \"$name=(\${${name}[@]})  \""
        fi
      done
    out " "
    out " "
  fi

  if [[ -n $(filter_option_type param) ]]; then
    if ((piped)); then
      debug "Ignorar parâmetros para arquivos .env"
    else
      out "## ${col_grn}parâmetros${col_reset}:"
      filter_option_type param |
        while read -r name; do
          # shellcheck disable=SC2015
          ((piped)) && eval "echo \"$name=\\\"\${$name:-}\\\"\"" || eval "echo -n \"$name=\\\"\${$name:-}\\\"  \""
        done
      echo " "
    fi
  fi
}

filter_option_type() {
  list_options | grep "$1|" | cut -d'|' -f3 | sort | grep -v '^\s*$'
}

init_options() {
  local init_command
  init_command=$(list_options |
    grep -v "verbose|" |
    awk '
    BEGIN { FS="|"; OFS=" ";}
    $1 ~ /flag/   && $5 == "" {print $3 "=0; "}
    $1 ~ /flag/   && $5 != "" {print $3 "=\"" $5 "\"; "}
    $1 ~ /option/ && $5 == "" {print $3 "=\"\"; "}
    $1 ~ /option/ && $5 != "" {print $3 "=\"" $5 "\"; "}
    $1 ~ /list/ {print $3 "=(); "}
    $1 ~ /secret/ {print $3 "=\"\"; "}
    ')
  if [[ -n "$init_command" ]]; then
    eval "$init_command"
  fi
}

expects_single_params() { list_options | grep 'param|1|' >/dev/null; }
expects_optional_params() { list_options | grep 'param|?|' >/dev/null; }
expects_multi_param() { list_options | grep 'param|n|' >/dev/null; }

parse_options() {
  if [[ $# -eq 0 ]]; then
    show_usage >&2
    safe_exit
  fi

  ## primeiro processe todos os -x --xxxx flags e opções
  while true; do
    # flag <flag> é salvo como $flag = 0/1
    # option <option> é salvo como $option
    if [[ $# -eq 0 ]]; then
      ## todos os parâmetros processados
      break
    fi
    if [[ ! $1 == -?* ]]; then
      ## todas as flags/opções processadas
      break
    fi
    local save_option
    save_option=$(list_options |
      awk -v opt="$1" '
        BEGIN { FS="|"; OFS=" ";}
        $1 ~ /flag/   &&  "-"$2 == opt {print $3"=1"}
        $1 ~ /flag/   && "--"$3 == opt {print $3"=1"}
        $1 ~ /option/ &&  "-"$2 == opt {print $3"=$2; shift"}
        $1 ~ /option/ && "--"$3 == opt {print $3"=$2; shift"}
        $1 ~ /list/ &&  "-"$2 == opt {print $3"+=($2); shift"}
        $1 ~ /list/ && "--"$3 == opt {print $3"=($2); shift"}
        $1 ~ /secret/ &&  "-"$2 == opt {print $3"=$2; shift #noshow"}
        $1 ~ /secret/ && "--"$3 == opt {print $3"=$2; shift #noshow"}
        ')
    if [[ -n "$save_option" ]]; then
      if echo "$save_option" | grep shift >>/dev/null; then
        local save_var
        save_var=$(echo "$save_option" | cut -d= -f1)
        debug "$config_icon parâmetro: ${save_var}=$2"
      else
        debug "$config_icon flag       : $save_option"
      fi
      eval "$save_option"
    else
      die "não consigo interpretar a opção [$1]"
    fi
    shift
  done

  ((help)) && (
    show_usage
    check_last_version
    out "                                  "
    echo "### DICAS E EXEMPLOS"
    show_tips

  ) && safe_exit


  ## executar parâmetros fornecidos
  if expects_single_params; then
    single_params=$(list_options | grep 'param|1|' | cut -d'|' -f3)
    list_singles=$(echo "$single_params" | xargs)
    single_count=$(echo "$single_params" | count_words)
    debug "$config_icon Esperar    : $single_count parâmetro(s) único(s): $list_singles"
    [[ $# -eq 0 ]] && die "precisa do(s) parâmetro(s) [$list_singles]"

    for param in $single_params; do
      [[ $# -eq 0 ]] && die "precisa do parâmetro [$param]"
      [[ -z "$1" ]] && die "precisa do parâmetro [$param]"
      debug "$config_icon Atribuir   : $param=$1"
      eval "$param=\"$1\""
      shift
    done
  else
    debug "$config_icon Nenhum parâmetro único para processar"
    single_params=""
    single_count=0
  fi

  if expects_optional_params; then
    optional_params=$(list_options | grep 'param|?|' | cut -d'|' -f3)
    optional_count=$(echo "$optional_params" | count_words)
    debug "$config_icon Esperar : $optional_count parâmetro(s) opcional(is): $(echo "$optional_params" | xargs)"

    for param in $optional_params; do
      debug "$config_icon Atribuir : $param=${1:-}"
      eval "$param=\"${1:-}\""
      shift
    done
  else
    debug "$config_icon Nenhum parâmetro opcional para processar"
    optional_params=""
    optional_count=0
  fi

  if expects_multi_param; then
    #debug "Process: multi param"
    multi_count=$(list_options | grep -c 'param|n|')
    multi_param=$(list_options | grep 'param|n|' | cut -d'|' -f3)
    debug "$config_icon Esperar : $multi_count multiparâmetro: $multi_param"
    ((multi_count > 1)) && die "não pode ter >1 'multi' parâmetro: [$multi_param]"
    ((multi_count > 0)) && [[ $# -eq 0 ]] && die "precisa do parâmetro (multi) [$multi_param]"
    # salva o resto dos parâmetros no multi param
    if [[ -n "$*" ]]; then
      debug "$config_icon Atribuir : $multi_param=$*"
      eval "$multi_param=( $* )"
    fi
  else
    multi_count=0
    multi_param=""
    [[ $# -gt 0 ]] && die "não pode interpretar parâmetros extras"
  fi
}

require_binary() {
  binary="$1"
  path_binary=$(command -v "$binary" 2>/dev/null)
  [[ -n "$path_binary" ]] && debug "️$require_icon required [$binary] -> $path_binary" && return 0
  #
  words=$(echo "${2:-}" | wc -l)
  case $words in
  0) install_instructions="$install_package $1" ;;
  1) install_instructions="$install_package $2" ;;
  *) install_instructions="$2" ;;
  esac
  alert "$script_basename needs [$binary] mas não pode ser encontrado"
  alert "1) install package  : $install_instructions"
  alert "2) check path       : export PATH=\"[path of your binary]:\$PATH\""
  die "Ausente programa/script [$binary]"
}

folder_prep() {
  if [[ -n "$1" ]]; then
    local folder="$1"
    local max_days=${2:-365}
    if [[ ! -d "$folder" ]]; then
      debug "$clean_icon Criar pasta : [$folder]"
      mkdir -p "$folder"
    else
      debug "$clean_icon Limpeza da pasta: [$folder] - excluir arquivos com mais de $max_days dia(s)"
      find "$folder" -mtime "+$max_days" -type f -exec rm {} \;
    fi
  fi
}

count_words() { wc -w | awk '{ gsub(/ /,""); print}'; }

recursive_readlink() {
  [[ ! -L "$1" ]] && echo "$1" && return 0
  local file_folder
  local link_folder
  local link_name
  file_folder="$(dirname "$1")"
  # resolver em relação ao caminho absoluto
  [[ "$file_folder" != /* ]] && link_folder="$(cd -P "$file_folder" &>/dev/null && pwd)"
  local symlink
  symlink=$(readlink "$1")
  link_folder=$(dirname "$symlink")
  link_name=$(basename "$symlink")
  [[ -z "$link_folder" ]] && link_folder="$file_folder"
  [[ "$link_folder" == \.* ]] && link_folder="$(cd -P "$file_folder" && cd -P "$link_folder" &>/dev/null && pwd)"
  debug "$info_icon Symbolic ln: $1 -> [$symlink]"
  recursive_readlink "$link_folder/$link_name"
}

lookup_script_data() {
  script_prefix=$(basename "${BASH_SOURCE[0]}" .sh)
  script_basename=$(basename "${BASH_SOURCE[0]}")
  execution_h=$(date "+%H:%M")
  execution_day=$(date "+%Y-%m-%d")
  execution_year=$(date "+%Y")

  script_install_path="${BASH_SOURCE[0]}"
  debug "$info_icon Script path: $script_install_path"
  script_install_path=$(recursive_readlink "$script_install_path")
  debug "$info_icon Linked path: $script_install_path"
  script_install_folder="$(cd -P "$(dirname "$script_install_path")" && pwd)"
  debug "$info_icon Diretório  : $script_install_folder"
  local script_hash="?"
  local script_lines="?"
  if [[ -f "$script_install_path" ]]; then
    script_hash=$(hash <"$script_install_path" 8)
    script_lines=$(awk <"$script_install_path" 'END {print NR}')
  fi

  # get shell/operating system/versions
  local shell_brand="sh"
  local shell_version="?"
  [[ -n "${ZSH_VERSION:-}" ]] && shell_brand="zsh" && shell_version="$ZSH_VERSION"
  [[ -n "${BASH_VERSION:-}" ]] && shell_brand="bash" && shell_version="$BASH_VERSION"
  [[ -n "${FISH_VERSION:-}" ]] && shell_brand="fish" && shell_version="$FISH_VERSION"
  [[ -n "${KSH_VERSION:-}" ]] && shell_brand="ksh" && shell_version="$KSH_VERSION"
  debug "$info_icon Shell type : $shell_brand - version $shell_version"

  local os_kernel
  local os_version
  local os_machine
  local os_name
  os_kernel=$(uname -s)
  os_version=$(uname -r)
  os_machine=$(uname -m)
  os_name="?"
  install_package=""
  case "$os_kernel" in
  CYGWIN* | MSYS* | MINGW*)
    os_name="Windows"
    ;;
  Darwin)
    os_name=$(sw_vers -productName)       # macOS
    os_version=$(sw_vers -productVersion) # 11.1
    install_package="brew install"
    ;;
  Linux | GNU*)
    if [[ $(command -v lsb_release) ]]; then
      # 'normal' Linux distributions
      os_name=$(lsb_release -i | awk -F: '{$1=""; gsub(/^[\s\t]+/,"",$2); gsub(/[\s\t]+$/,"",$2); print $2}')    # Ubuntu/Raspbian
      os_version=$(lsb_release -r | awk -F: '{$1=""; gsub(/^[\s\t]+/,"",$2); gsub(/[\s\t]+$/,"",$2); print $2}') # 20.04
    else
      # Synology, QNAP,
      os_name="Linux"
    fi
    [[ -x /bin/apt-cyg ]] && install_package="apt-cyg install"     # Cygwin
    [[ -x /bin/dpkg ]] && install_package="dpkg -i"                # Synology
    [[ -x /opt/bin/ipkg ]] && install_package="ipkg install"       # Synology
    [[ -x /usr/sbin/pkg ]] && install_package="pkg install"        # BSD
    [[ -x /usr/bin/pacman ]] && install_package="pacman -S"        # Arch Linux
    [[ -x /usr/bin/zypper ]] && install_package="zypper install"   # Suse Linux
    [[ -x /usr/bin/emerge ]] && install_package="emerge"           # Gentoo
    [[ -x /usr/bin/yum ]] && install_package="yum install"         # RedHat RHEL/CentOS/Fedora
    [[ -x /usr/bin/apk ]] && install_package="apk add"             # Alpine
    [[ -x /usr/bin/apt-get ]] && install_package="apt-get install" # Debian
    [[ -x /usr/bin/apt ]] && install_package="apt install"         # Ubuntu
    ;;

  esac
  debug "$info_icon System OS  : $os_name ($os_kernel) $os_version on $os_machine"
  debug "$info_icon Package mgt: $install_package"

  # obtém a data da última modificação deste script
  script_modified="??"
  [[ "$os_kernel" == "Linux" ]] && script_modified=$(stat -c %y "$script_install_path" 2>/dev/null | cut -c1-16) # generic linux
  [[ "$os_kernel" == "Darwin" ]] && script_modified=$(stat -f "%Sm" "$script_install_path" 2>/dev/null)          # for MacOS

  debug "$info_icon Script ID  : $script_lines lines / md5: $script_hash"
  debug "$info_icon Criado     : $script_created"
  debug "$info_icon Modificado : $script_modified"
  debug "$info_icon Executando : $USER@$HOSTNAME"

  # se executado dentro de um repositório git, detecta para qual repositório remoto ele é
  if git status &>/dev/null; then
    git_repo_remote=$(git remote -v | awk '/(fetch)/ {print $2}')
    debug "$info_icon git remote : $git_repo_remote"
    git_repo_root=$(git rev-parse --show-toplevel)
    debug "$info_icon git folder : $git_repo_root"
  else
    readonly git_repo_root=""
    readonly git_repo_remote=""
  fi

  # obtém a versão do script do arquivo VERSION.md - que é atualizado automaticamente por pforret/setver
  [[ -f "$script_install_folder/VERSION.md" ]] && script_version=$(cat "$script_install_folder/VERSION.md")
  # obtém a versão do script git tag - que é atualizado automaticamente por pforret/setver
  [[ -n "$git_repo_root" ]] && [[ -n "$(git tag &>/dev/null)" ]] && script_version=$(git tag --sort=version:refname | tail -1)
}

# obtém a versão do script do arquivo VERSION.md - que é atualizado automaticamente pelo pforret/setver
# obtém a versão do script do git tag file - que é atualizado automaticamente pelo pforret/setver

prep_log_and_temp_dir() {
  tmp_file=""
  log_file=""
  if [[ -n "${tmp_dir:-}" ]]; then
    folder_prep "$tmp_dir" 1
    tmp_file=$(mktemp "$tmp_dir/$execution_day.XXXXXX")
    debug "$config_icon tmp_file: $tmp_file"
    # você pode usar este arquivo temporário em seu programa
    # será deletado automaticamente se o programa terminar sem problemas
  fi
  if [[ -n "${log_dir:-}" ]]; then
    folder_prep "$log_dir" 30
    log_file="$log_dir/$script_prefix.$execution_day.log"
    debug "$config_icon log_file: $log_file"
  fi
}

import_env_if_any() {
  env_files=("$script_install_folder/.env" "$script_install_folder/$script_prefix.env" "./.env" "./$script_prefix.env")
  for env_file in "${env_files[@]}"; do
    if [[ -f "$env_file" ]]; then
      debug "$config_icon Ler configuração de [$env_file]"
      # shellcheck disable=SC1090
      source "$env_file"
    fi
  done
}

# Configurações de saída
initialise_output
# encontrar pasta de instalação
lookup_script_data

[[ $run_as_root == 1 ]] && [[ $UID -ne 0 ]] && die "o usuário é $USER, DEVE ser root para ser executado [$script_basename]"
[[ $run_as_root == -1 ]] && [[ $UID -eq 0 ]] && die "o usuário é $USER, NÃO PODE ser root para executar [$script_basename]"

# definir valores padrão para flags/options
init_options
# sobrescrever com .env se houver
import_env_if_any

if [[ $sourced -eq 0 ]]; then
  # sobrescrever as opções especificadas, se houver
  parse_options "$@"
  # limpa a pasta debug e temp
  prep_log_and_temp_dir
  # executa o programa principal
  main
  # sair e limpar
  safe_exit
else
  # desabilitar o trap, não executar main
  trap - INT TERM EXIT
fi
