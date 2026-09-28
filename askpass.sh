#!/bin/bash
# Спрашивает пароль от Mac системным окном вместо терминала.
# Нужен, чтобы установку мог вести Claude Code: у него нет живого терминала,
# куда человек набрал бы пароль. sudo -A и Homebrew зовут этот файл сами.
exec /usr/bin/osascript \
  -e 'text returned of (display dialog "Установке нужен пароль от этого Mac (тот, которым ты входишь в систему)." default answer "" with hidden answer with title "МосФорум: установка" with icon caution buttons {"Отмена", "OK"} default button "OK" cancel button "Отмена")'
