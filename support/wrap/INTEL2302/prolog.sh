#!/bin/bash

host=$(hostname)

if [[ "$host" == "belenos"* || "$host" == "taranis"* ]]
then
  . $prefix/prolog-meteo.sh
elif [[ "$host" == *"leonardo"* ]]
then
  . $prefix/prolog-leonardo.sh
else
  exit 1
fi


