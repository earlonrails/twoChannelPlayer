#!/bin/bash

if $(command -v mxmlc >/dev/null 2>&1); then
	MXML=`which mxmlc`
else
	MXML=/Developer/AdobeFlex4SDK/bin/mxmlc
fi

"$MXML" -static-link-runtime-shared-libraries=true src/main.mxml --output two_channel_player.swf
