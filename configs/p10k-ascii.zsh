# Powerlevel10k ASCII overrides for terminals without a Nerd Font.
#
# This file is sourced AFTER configs/p10k.zsh by default. It replaces all
# Nerd Font glyphs (powerline separators, branch icons, etc.) with plain
# Unicode characters that render correctly in any modern terminal.
# Set NETSHOOT_NERDFONT=1 to skip this file and use the full Nerd Font prompt.
#
# Usage (applied by default; skip with NETSHOOT_NERDFONT=1):
#   docker run -it --rm obeoneorg/netshoot
#   docker run -it --rm -e NETSHOOT_NERDFONT=1 obeoneorg/netshoot  # Nerd Font

() {
  emulate -L zsh -o extended_glob

  # Switch from Nerd Font glyphs to standard Unicode characters.
  typeset -g POWERLEVEL9K_MODE=unicode

  # Replace powerline separator glyphs with simple Unicode arrows.
  typeset -g POWERLEVEL9K_LEFT_SUBSEGMENT_SEPARATOR='%244F|'
  typeset -g POWERLEVEL9K_RIGHT_SUBSEGMENT_SEPARATOR='%244F|'
  typeset -g POWERLEVEL9K_LEFT_SEGMENT_SEPARATOR='>'
  typeset -g POWERLEVEL9K_RIGHT_SEGMENT_SEPARATOR='<'
  typeset -g POWERLEVEL9K_LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL='>'
  typeset -g POWERLEVEL9K_RIGHT_PROMPT_FIRST_SEGMENT_START_SYMBOL='<'
  typeset -g POWERLEVEL9K_LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL=''
  typeset -g POWERLEVEL9K_RIGHT_PROMPT_LAST_SEGMENT_END_SYMBOL=''

  # Replace Nerd Font branch icon with a Unicode symbol.
  typeset -g POWERLEVEL9K_VCS_BRANCH_ICON='@ '
}
