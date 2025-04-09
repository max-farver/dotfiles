# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME=""

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git fzf-tab zsh-vi-mode zsh-autosuggestions zsh-syntax-highlighting golang jsontools kubectl)

source $ZSH/oh-my-zsh.sh

eval "$(direnv hook zsh)"

# User configuration
alias dotfiles='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='nvim'
else
  export EDITOR='nvim'
fi

# use vi key bindings
# bindkey -v
# avoid the annoying backspace/delete issue 
# where backspace stops deleting characters
# bindkey -v '^?' backward-delete-char

export XDG_CONFIG_HOME="$HOME/.config"

export DISABLE_AUTO_TITLE='true'

export PATH="/opt/homebrew/opt/postgresql@16/bin:$PATH"

alias nvim="/opt/homebrew/bin/nvim"

export NVM_DIR=~/.nvm
source $(brew --prefix nvm)/nvm.sh

export PATH="/opt/homebrew/bin:$PATH"

export NVM_DIR="$HOME/.nvm"
  [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"  # This loads nvm
  [ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion

export GH_DASH_CONFIG=$HOME/gh-dash/config.yml

export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_DEFAULT_OPTS='--height 40% --layout reverse --info=inline --prompt "Search: " --pointer ">" --multi --bind "ctrl-a:select-all,ctrl-e:execute(nvim {+})"'
export FZF_CTRL_T_COMMAND="${FZF_DEFAULT_COMMAND}"
source <(fzf --zsh)
######################  AWS Helpers  ############################################

alias awslogin="aws sso login --profile daily-login"

function awsprofile {
  aws configure list-profiles | fzf | export AWS_PROFILE=$(cat)
}


######################  K8s Helpers  ############################################
function copytopod {
    readonly pod=${1:?"Specify pod name"}
    readonly container=${2:?"Specify container name"}
    readonly src=${3:?"Specify source file"}
    readonly dest=${4:?"Specify destination file"}

    kubectl cp "$src" "$pod":"$dest" -c "$container"
}

function copyfrompod {
    readonly pod=${1:?"Specify pod name"}
    readonly container=${2:?"Specify container name"}
    readonly src=${3:?"Specify source file"}
    readonly dest=${4:?"Specify destination file"}

    kubectl cp "$pod":"$src" "$dest" -c "$container"
}


######################  Git Helpers  ############################################

function gitbranch {
    if [ -d .git ]; then
        git rev-parse --symbolic-full-name --abbrev-ref HEAD
    else
        echo "Not a git repository"
    fi
}

function forcepush {
    current_branch=$(gitbranch)
    if read -q "?Force push to $current_branch? [y/N]"; then
        print "\n"
        git push origin "$current_branch" --force
    fi
}

######################  Misc Helpers  ############################################
alias lg='lazygit'
alias gd='gh dash'
alias lzd='lazydocker'o

function rgfzf {
  RG_PREFIX="rg --column --line-number --no-heading --color=always --smart-case "
  INITIAL_QUERY="${*:-}"
  fzf --ansi --disabled --query "$INITIAL_QUERY" \
      --bind "start:reload:$RG_PREFIX {q}" \
      --bind "change:reload:sleep 0.1; $RG_PREFIX {q} || true" \
      --delimiter : \
      --preview 'bat --color=always {1} --highlight-line {2}' \
      --preview-window 'up,60%,border-bottom,+{2}+3/3,~3'
}

function grep_docker_logs {
  temp_file=$(mktemp --suffix=".log")

  container_name=$(docker container ls --format "{{.Names}}" | fzf)
  docker logs "$container_name" >& "$temp_file"

  GREP_PREFIX="grep -r --line-number --color=always "
  INITIAL_QUERY="${*:-}"

  fzf --ansi --disabled --query "$INITIAL_QUERY" \
      --bind "start:reload:$GREP_PREFIX {q} $temp_file" \
      --bind "change:reload:sleep 0.1; $GREP_PREFIX {q} $temp_file || true" \
      --delimiter : \
      --preview 'bat --color=always {1} --highlight-line {2}' \
      --preview-window 'up,60%,border-bottom,+{2}+3/3,~3'

  rm "$temp_file"
}

#### tmux ####

function tmuxsess {
  session_name=$(fd . ~/.tmux/tmuxp | fzf --tmux 70%)
  tmuxp load $session_name
}

alias init_tmuxp_configs='~/.tmux/scripts/create_tmuxp_configs.sh'


######################  Source Other Configs  #####################################

for file in ~/.config/zsh-helpers/extensions/.[^.]*; do
    source "$file"
done

eval "$(starship init zsh)"
