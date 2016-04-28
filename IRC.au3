#include-once
#include <Array.au3>
#include <FileConstants.au3>
#include <GUIConstantsEx.au3>
#include <GuiEdit.au3>
#include <StringConstants.au3>
#include <WindowsConstants.au3>

#AutoIt3Wrapper_Au3Check_Parameters=-q -d -w 1 -w 2 -w 3 -w- 4 -w 5 -w 6 -w- 7

; #INDEX# =======================================================================================================================
; Title ............: TheDcoder's IRC UDF.
; AutoIt Version ...: 3.3.14.1
; Description ......: IRC UDF. Full compliance with RFC 2812 IRCv3.
; Author(s) ........: Damon Harris (TheDcoder)
; Special Thanks....: Robert C. Maehl (rcmaehl) for making his version of IRC UDF which taught me the basics of TCP and IRC :)
; Link .............: ...
; Important Links ..: IRCv3                    - http://ircv3.net
;                     RFC 2812                 - https://tools.ietf.org/html/rfc2812
;                     List of all IRC Numerics - http://defs.ircdocs.horse/defs/numerics.html
; ===============================================================================================================================

; #CURRENT# =====================================================================================================================
; _IRC_AuthPlainSASL
; _IRC_CapRequire
; _IRC_CapEnd
; _IRC_Connect
; _IRC_Disconnect
; _IRC_FormatMessage
; _IRC_FormatPrivMsg
; _IRC_Invite
; _IRC_IsChannel
; _IRC_JoinChannel
; _IRC_Kick
; _IRC_Part
; _IRC_Pong
; _IRC_Quit
; _IRC_ReceiveRaw
; _IRC_SendMessage
; _IRC_SendNotice
; _IRC_SendRaw
; _IRC_SetMode
; _IRC_SetNick
; _IRC_SetUser
; _IRC_WaitForNextMsg
; ===============================================================================================================================

; #INTERNAL_USE_ONLY# ===========================================================================================================
; <None>
; ===============================================================================================================================

; #CONSTANTS# ===================================================================================================================
Global Enum $IRC_MSGFORMAT_PREFIX, $IRC_MSGFORMAT_COMMAND
Global Enum $IRC_PRIVMSG_SENDER, $IRC_PRIVMSG_SENDER_USERSTRING, $IRC_PRIVMSG_SENDER_HOSTMASK, $IRC_PRIVMSG_RECEIVER, $IRC_PRIVMSG_MSG, $IRC_PRIVMSG_REPLYTO

Global Const $IRC_MODE_ADD = '+'
Global Const $IRC_MODE_REMOVE = '-'

Global Const $IRC_TRAILING_PARAMETER_INDICATOR = ':'

Global Const $IRC_SASL_LOGGEDIN = 900
Global Const $IRC_SASL_LOGGEDOUT = 901
Global Const $IRC_SASL_NICKLOCKED = 902
Global Const $IRC_SASL_SASLSUCCESS = 903
Global Const $IRC_SASL_SASLFAIL = 904
Global Const $IRC_SASL_SASLTOOLONG = 905
Global Const $IRC_SASL_SASLABORTED = 906
Global Const $IRC_SASL_SASLALREADY = 907
Global Const $IRC_SASL_SASLMECHS = 908
; ===============================================================================================================================

; #VARIABLES# ===================================================================================================================
Global $__g_iIRC_CharEncoding = $SB_UTF8 ; Use $SB_* Constants if you need to change the encoding (see doc for StringToBinary)
Global $__g_IRC_sLoggingFunction = "__IRC_DefaultLog"
; ===============================================================================================================================

TCPStartup() ; Start TCP Services

; #FUNCTION# ====================================================================================================================
; Name ..........: _IRC_AuthPlainSASL
; Description ...: Authenticate yourself to the server using SASL PLAIN mech.
; Syntax ........: _IRC_AuthPlainSASL($iSocket, $sUsername, $sPassword)
; Parameters ....: $iSocket             - $iSocket from _IRC_Connect.
;                  $sUsername           - Your $sUsername.
;                  $sPassword           - Your $sPassoword.
; Return values .: Success: True
;                  Failure: False & @error is set (refer to code.)
; Author ........: Damon Harris (TheDcoder)
; Modified ......:
; Remarks .......:
; Related .......:
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _IRC_AuthPlainSASL($iSocket, $sUsername, $sPassword)
	If Not _IRC_CapRequire($iSocket, 'multi-prefix sasl') Then Return SetError(6, 0, False)
	If @error Then Return SetError(2, @extended, False)
	_IRC_SendRaw($iSocket, "AUTHENTICATE PLAIN")
	If @error Then Return SetError(5, @extended, False)
	If Not _IRC_WaitForNextMsg($iSocket, True)[$IRC_MSGFORMAT_COMMAND] = "AUTHENTICATE" Then Return SetError(3, @extended, False)
	;If @error Then SetError(3, @extended, False)
	_IRC_SendRaw($iSocket, "AUTHENTICATE " & StringReplace(__IRC_Base64_Encode($sUsername & Chr(0) & $sUsername & Chr(0) & $sPassword), @CRLF, ''))
	If @error Then Return SetError(5, @error, @extended)
	Local $aMessage = _IRC_WaitForNextMsg($iSocket, True)
	If @error Then Return SetError(4, @extended, False)
	If Not ($aMessage[$IRC_MSGFORMAT_COMMAND] = $IRC_SASL_LOGGEDIN Or $aMessage[$IRC_MSGFORMAT_COMMAND] = $IRC_SASL_SASLSUCCESS) Then Return SetError(1, $aMessage[$IRC_MSGFORMAT_COMMAND], False)
	_IRC_CapEnd($iSocket)
	Return True
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _IRC_CapRequire
; Description ...: Require a capacility.
; Syntax ........: _IRC_CapRequire($iSocket, $sCapability)
; Parameters ....: $iSocket             - $iSocket from _IRC_Connect.
;                  $sCapability         - Name of the the $sCapability.
; Return values .: Success: True if the capability is acknowlodged.
;                  Failure: False & @error is set if sending the message to the server failed, @extended is set to TCPSend's @error.
; Author ........: Damon Harris (TheDcoder)
; Modified ......:
; Remarks .......:
; Related .......:
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _IRC_CapRequire($iSocket, $sCapability)
	_IRC_SendRaw($iSocket, 'CAP REQ :' & $sCapability)
	If @error Then Return SetError(1, @extended, False)
	Local $aMessage
	Do
		$aMessage = _IRC_WaitForNextMsg($iSocket, True)
		If @error Then Return SetError(2, @extended, False)
	Until $aMessage[$IRC_MSGFORMAT_COMMAND] = "CAP"
	Return $aMessage[3] = "ACK"
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _IRC_CapEnd
; Description ...: Sends the CAP END message.
; Syntax ........: _IRC_CapEnd($iSocket)
; Parameters ....: $iSocket             - $iSocket from _IRC_Connect.
; Return values .: Success: True
;                  Failure: False & @extended set to TCPRecv's @error.
; Author ........: Damon Harris (TheDcoder)
; Modified ......:
; Remarks .......:
; Related .......:
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _IRC_CapEnd($iSocket)
	_IRC_SendRaw($iSocket, 'CAP END')
	If @error Then SetError(1, @extended, False)
	Return True
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _IRC_Connect
; Description ...: Just a wrapper to TCPConnect, Use it to get the $iSocket used to send messages to the IRC Server.
; Syntax ........: _IRC_Connect($vServer, $iPort)
; Parameters ....: $vServer             - The IP or Address of the IRC Server.
;                  $iPort               - The port to connect. DONT USE SSL PORTS!.
; Return values .: Success: $iSocket
;                  Failure: False & @error set to:
;                           1 - If unable to resolve server address, @extended is set to TCPNameToIP's @error
;                           2 - If unable to establish a connection to the server, @extended is set to TCPConnect's @error
; Author ........: Damon Harris (TheDcoder)
; Modified ......:
; Remarks .......: SSL is not supported yet :(
; Related .......: TCPConnect
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _IRC_Connect($vServer, $iPort)
	$vServer = TCPNameToIP($vServer)
	If @error Then Return SetError(1, @error, False)
	Local $iSocket = TCPConnect($vServer, $iPort)
	If @error Then Return SetError(2, @error, False)
	Return $iSocket
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _IRC_Disconnect
; Description ...: Just a wrapper for TCPCloseSocket.
; Syntax ........: _IRC_Disconnect($iSocket)
; Parameters ....: $iSocket             - $iSocket from _IRC_Connect.
; Return values .: Success: True
;                  Failure: False & @error set to 1, @extended is set to TCPCloseSocket's @error.
; Author ........: Damon Harris (TheDcoder)
; Modified ......:
; Remarks .......:
; Related .......: TCPCloseSocket
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _IRC_Disconnect($iSocket)
	TCPCloseSocket($iSocket)
	If @error Then Return SetError(1, @error, False)
	Return True
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _IRC_FormatMessage
; Description ...: Formats a RAW message from to IRC into a neat array ;).
; Syntax ........: _IRC_FormatMessage($sMessage)
; Parameters ....: $sMessage            - The raw $sMessage from the server.
; Return values .: Success: Formatted Array, See Remarks for format.
;                  Failure: Not gonna happen lol.
; Author ........: Damon Harris (TheDcoder)
; Modified ......:
; Remarks .......: Format of the returned array:
;                  $aArray[$IRC_MSGFORMAT_PREFIX]  = Prefix of the message (Refer to <prefix> in 2.3.1 section of RFC 1459)
;                  $aArray[$IRC_MSGFORMAT_COMMAND] = Command (like PRIVMSG, MODE etc.)
;                  $aArray[1 + n]                  = nth parameter (Example: The second parameter would be located in $aArray[3])
;
;                  Not all formatted arrays make sense :P
; Related .......:
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _IRC_FormatMessage($sMessage)
	Local $aMessage = StringSplit($sMessage, ' ')
	Local $iStart = 2
	Local $aPrefixArray[2]
	$aMessage[$aMessage[0]] = StringTrimRight($aMessage[$aMessage[0]], 2) ; Trim @CRLF
	If StringLeft($aMessage[1], 1) = $IRC_TRAILING_PARAMETER_INDICATOR Then
		$iStart = 3
		$aPrefixArray[$IRC_MSGFORMAT_PREFIX] = StringTrimLeft($aMessage[1], 1)
		$aPrefixArray[$IRC_MSGFORMAT_COMMAND] = $aMessage[2]
	Else
		$aPrefixArray[$IRC_MSGFORMAT_PREFIX] = ""
		$aPrefixArray[$IRC_MSGFORMAT_COMMAND] = $aMessage[1]
	EndIf
	For $i = $iStart To $aMessage[0]
		If StringLeft($aMessage[$i], 1) = $IRC_TRAILING_PARAMETER_INDICATOR Then
			$aMessage[$i] = StringTrimLeft(_ArrayToString($aMessage, ' ', $i, $aMessage[0]), 1)
			If Not $i = $aMessage[0] Then _ArrayDelete($aMessage, ($i + 1) & '-' & $aMessage[0])
			ExitLoop
		EndIf
	Next
	_ArrayConcatenate($aPrefixArray, $aMessage, $iStart)
	Return $aPrefixArray
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _IRC_FormatPrivMsg
; Description ...: Formats a PRIVMSG into nice & readable array ;)
; Syntax ........: _IRC_FormatPrivMsg($vMessage)
; Parameters ....: $vMessage            - The RAW Message or Formatted Message from _IRC_FormatMessage.
; Return values .: Success: $aFormattedArray (See Remarks).
;                  Failure: Empty $aFormattedArray & @error is set to:
;                           1 - If the $vMessage is not a PRIV message.
;                           2 - If the $vMessage's prefix is faulty.
; Author ........: Damon Harris (TheDcoder)
; Modified ......:
; Remarks .......: Format of $aFormattedArray:
;                  $aFormattedArray[$IRC_PRIVMSG_SENDER] = <Nickname of the sender>
;                  $aFormattedArray[$IRC_PRIVMSG_SENDER_USERSTRING] = <The "user" string of the sender>
;                  $aFormattedArray[$IRC_PRIVMSG_SENDER_HOSTMASK] = <Hostmask of the sender>
;                  $aFormattedArray[$IRC_PRIVMSG_RECEIVER] = <Name of the channel/your nickname>
;                  $aFormattedArray[$IRC_PRIVMSG_MSG] = <Message sent>
;                  $aFormattedArray[$IRC_PRIVMSG_REPLYTO] = <Contains the $sTarget parameter need for _IRC_SendMessage>
; Related .......:
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _IRC_FormatPrivMsg($vMessage)
	If Not IsArray($vMessage) Then
		$vMessage = _IRC_FormatMessage($vMessage)
		If @error Then Return SetError(1, 0, False)
	EndIf
	Local $aFormattedArray[6]
	If Not $vMessage[$IRC_MSGFORMAT_COMMAND] = "PRIVMSG" Then Return SetError(1, 0, $aFormattedArray)
	Local $aSenderDetails = StringSplit($vMessage[$IRC_MSGFORMAT_PREFIX], '!@')
	Local Enum $PARM_COUNT, $NICKNAME, $USERSTRING, $HOSTMASK
	If $aSenderDetails[$PARM_COUNT] < 3 Then Return SetError(2, 0, $aFormattedArray)
	$aFormattedArray[$IRC_PRIVMSG_SENDER] = $aSenderDetails[$NICKNAME]
	$aFormattedArray[$IRC_PRIVMSG_SENDER_USERSTRING] = $aSenderDetails[$USERSTRING]
	$aFormattedArray[$IRC_PRIVMSG_SENDER_HOSTMASK] = $aSenderDetails[$HOSTMASK]
	$aFormattedArray[$IRC_PRIVMSG_RECEIVER] = $vMessage[2]
	$aFormattedArray[$IRC_PRIVMSG_MSG] = $vMessage[3]
	$aFormattedArray[$IRC_PRIVMSG_REPLYTO] = (_IRC_IsChannel($aFormattedArray[$IRC_PRIVMSG_RECEIVER])) ? $aFormattedArray[$IRC_PRIVMSG_RECEIVER] : $aFormattedArray[$IRC_PRIVMSG_SENDER]
	Return $aFormattedArray
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _IRC_Invite
; Description ...: Invite a user to a channel
; Syntax ........: _IRC_Invite($iSocket, $sNick, $sChannel)
; Parameters ....: $iSocket             - $iSocket from _IRC_Connect.
;                  $sNick               - $sNickname of the use to invite.
;                  $sChannel            - $sChannel to invite.
; Return values .:Success: Raw data (most of the time, its a string).
;                  Failure: False & @error set to 1, @extended contains TCPRecv's @error.
; Author ........: Damon Harris (TheDcoder)
; Modified ......:
; Remarks .......:
; Related .......:
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _IRC_Invite($iSocket, $sNick, $sChannel)
	_IRC_SendRaw($iSocket, "INVITE " & $sNick & ' ' & $sChannel)
	If @error Then Return SetError(1, @extended, False)
	Return True
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _IRC_IsChannel
; Description ...: Check if a string is a valid channel name
; Syntax ........: _IRC_IsChannel($sChannel)
; Parameters ....: $sChannel            - $sChannel name to check.
; Return values .: Success: True
;                  Failure: False
; Author ........: Damon Harris (TheDcoder)
; Modified ......:
; Remarks .......:
; Related .......:
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _IRC_IsChannel($sChannel)
	Switch StringLeft($sChannel, 1)
		Case '&', '#', '+', '!' ; RFC 2812 Section 1.3: "Channels"
			Return True

		Case Else
			Return False
	EndSwitch
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _IRC_ReceiveRaw
; Description ...: Get RAW messages from the server.
; Syntax ........: _IRC_ReceiveRaw($iSocket, $bSplit)
; Parameters ....: $iSocket             - $iSocket from _IRC_Connect.
; Return values .: Success: Raw data (most of the time, its a string).
;                  Failure: False & @error set to 1, @extended contains TCPRecv's @error.
; Author ........: Damon Harris (TheDcoder)
; Modified ......:
; Remarks .......:
; Related .......: TCPRecv
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _IRC_ReceiveRaw($iSocket)
	Local Const $UNICODE_LF = 10
	Local Const $UNICODE_NULL = 0
	Local $vData = ""
	Do
		$vData &= TCPRecv($iSocket, 1)
		If @error Then Return SetError(1, @error, False)
	Until AscW(StringRight($vData, 1)) = $UNICODE_LF Or AscW(StringRight($vData, 1)) = $UNICODE_NULL
	If Not $vData = "" Then Call($__g_IRC_sLoggingFunction, $vData, False)
	Return $vData
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _IRC_JoinChannel
; Description ...: Join a channel.
; Syntax ........: _IRC_JoinChannel($iSocket, $sChannel[, $sPassword = ""])
; Parameters ....: $iSocket             - $iSocket from _IRC_Connect.
;                  $sChannel            - Channel to join (Including the #).
;                  $sPassword           - [optional] Password of the channel (if any). Default is none ("").
; Return values .: Success: True (It does not check if Joining was successful or not.)
;                  Failure: False & @error set to:
;                           1 - If the channel's name is too long.
;                           2 - If sending the join message to the server failed, @extended is set to TCPSend's @error.
; Author ........: Damon Harris (TheDcoder)
; Modified ......:
; Remarks .......:
; Related .......:
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _IRC_JoinChannel($iSocket, $sChannel, $sPassword = "")
	Local $sRawMessage = "JOIN " & $sChannel & (($sPassword = "") ? ("") : (' :' & $sPassword))
	_IRC_SendRaw($iSocket, $sRawMessage)
	If @error Then Return SetError(@error, @extended, False)
	Return True
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _IRC_Pong
; Description ...: Reply to a server PING message.
; Syntax ........: _IRC_Pong($iSocket, $sServer)
; Parameters ....: $iSocket             - $iSocket from _IRC_Connect.
;                  $sServer             - Server's hostname.
; Return values .: Success: True
;                  Failure: False & @extended is set to TCPSend's @error.
; Author ........: Damon Harris (TheDcoder)
; Modified ......:
; Remarks .......:
; Related .......:
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _IRC_Pong($iSocket, $sServer)
	_IRC_SendRaw($iSocket, 'PONG ' & $sServer)
	If @error Then Return SetError(1, @extended, False)
	Return True
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _IRC_Kick
; Description ...: Kick a user from a channel.
; Syntax ........: _IRC_Kick($iSocket, $sChannel, $sNick, $sReason)
; Parameters ....: $iSocket             - $iSocket from _IRC_Connect.
;                  $sChannel            - In which $sChannel should the user kicked?
;                  $sNick               - $sNickname of the user to kick.
;                  $sReason             - [optional] Reason of kick, Default is "" (None).
; Return values .: Success: True
;                  Failure: False & @extended is set to TCPSend's @error.
; Author ........: Damon Harris (TheDcoder)
; Modified ......:
; Remarks .......:
; Related .......:
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _IRC_Kick($iSocket, $sChannel, $sNick, $sReason = "")
	_IRC_SendRaw($iSocket, "KICK " & $sChannel & ' ' & $sNick & (($sReason = "") ? ("") : (' :' & $sReason)))
	If @error Then Return SetError(1, @extended, False)
	Return True
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _IRC_Part
; Description ...: Part from a channel.
; Syntax ........: _IRC_Part($iSocket, $sChannel[, $sReason = ""])
; Parameters ....: $iSocket             - $iSocket from _IRC_Connect.
;                  $sChannel            - Name of the $sChannel to part (including the prefix).
;                  $sReason             - [optional] Reason for parting. Default is "" (None).
; Return values .: Success: True
;                  Failure: False & @extended is set to TCPSend's @error.
; Author ........: Damon Harris (TheDcoder)
; Modified ......:
; Remarks .......:
; Related .......:
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _IRC_Part($iSocket, $sChannel, $sReason = "")
	_IRC_SendRaw($iSocket, "PART " & $sChannel & (($sReason = "") ? ("") : (' :' & $sReason)))
	If @error Then Return SetError(1, @extended, False)
	Return True
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _IRC_Quit
; Description ...: Quit from a IRC server.
; Syntax ........: _IRC_Quit($iSocket[, $sReason = ""])
; Parameters ....: $iSocket             - an integer value.
;                  $sReason             - [optional] a string value. Default is "".
; Return values .: Success: True
;                  Failure: False & @extended is set to TCPSend's @error.
; Author ........: Damon Harris (TheDcoder)
; Modified ......:
; Remarks .......:
; Related .......:
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _IRC_Quit($iSocket, $sReason = "")
	_IRC_SendRaw($iSocket, 'QUIT ' & (($sReason = "") ? ("") : (' :' & $sReason)))
	If @error Then Return SetError(1, @extended, False)
	Return True
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _IRC_SendMessage
; Description ...: Use it to send a message/PM to a channel/user.
; Syntax ........: _IRC_SendMessage($iSocket, $sTarget, $sMessage)
; Parameters ....: $iSocket             - $iSocket from _IRC_Connect.
;                  $sTarget             - $sTarget or recipent of the messages, can be a channel or a nick.
;                  $sMessage            - $sMessage to send.
; Return values .: Success: True
;                  Failure: False & @error set to:
;                           1 - If the $sMessage is too long. (See _IRC_SendRaw's @error 1's reason)
;                           2 - If sending the message to the server failed, @extended is set to TCPSend's @error.
; Author ........: Damon Harris (TheDcoder)
; Modified ......:
; Remarks .......: WARNING: THIS FUNCTION DOES NOT SEND RAW MESSAGES TO THE SERVER, USE _IRC_SendRaw instead.
; Related .......:
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _IRC_SendMessage($iSocket, $sTarget, $sMessage)
	_IRC_SendRaw($iSocket, "PRIVMSG " & $sTarget & " :" & $sMessage)
	If @error Then Return SetError(@error, @extended, False)
	Return True
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _IRC_SendNotice
; Description ...: Send a notice to a channel or user.
; Syntax ........: _IRC_SendNotice($iSocket, $sTarget, $sMessage)
; Parameters ....: $iSocket             - $iSocket from _IRC_Connect.
;                  $sTarget             - $sTarget of the notice, can be a channel or a user.
;                  $sMessage            - $sMessage of the notification.
; Return values .: Success: True
;                  Failure: False & @extended is set to TCPSend's @error.
; Author ........: Damon Harris (TheDcoder)
; Modified ......:
; Remarks .......:
; Related .......:
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _IRC_SendNotice($iSocket, $sTarget, $sMessage)
	_IRC_SendRaw($iSocket, "NOTICE " & $sTarget & ' :' & $sMessage)
	If @error Then Return SetError(1, @extended, False)
	Return True
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _IRC_SendRaw
; Description ...: Just a wrapper for TCPSend, use it to send raw messeges to the IRC server.
; Syntax ........: _IRC_SendRaw($iSocket, $sRawMessage)
; Parameters ....: $iSocket             - $iSocket from _IRC_Connect.
;                  $sRawMessage         - The $sRawMessage to send.
; Return values .: Success: True. @extended is set to 1 if the $sRawMessage exceeds 512 chars. (This is required by protocol.)
;                  Failure: False & @error set to:
;                           1 - If the $sRawMessage is longer than 512 bytes.
;                           2 - If sending the message to the server failed, @extended is set to TCPSend's @error.
; Author ........: Damon Harris (TheDcoder)
; Modified ......:
; Remarks .......: 1. @CRLF is ALWAYS appended to the $sRawMessage. Its required by protocol.
;                  2. The $sRawMessage is converted to binary before sending it...
;                  3. Messages longer than 512 bytes are rejected by most of the IRC Server...
; Related .......: TCPSend
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _IRC_SendRaw($iSocket, $sRawMessage)
	$sRawMessage &= @CRLF
	Local $dRawMessage = StringToBinary($sRawMessage, $__g_iIRC_CharEncoding)
	If BinaryLen($dRawMessage) > 512 Then SetError(1, 0, False)
	TCPSend($iSocket, $dRawMessage)
	If @error Then Return SetError(2, @error, False)
	Call($__g_IRC_sLoggingFunction, $sRawMessage, True) ; Call the logging function
	Return True
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _IRC_SetNick
; Description ...: Changes or sets your nickname
; Syntax ........: _IRC_SetNick($iSocket, $sNick)
; Parameters ....: $iSocket             - $iSocket from _IRC_Connect.
;                  $sNick               - Nickname to set.
; Return values .: Success: True
;                  Failure: False & @extended is set to TCPSend's @error.
; Author ........: Damon Harris (TheDcoder)
; Modified ......:
; Remarks .......: WARNING: THE RETURN VALUES ONLY INDICATES THE DELIVARY OF THE MESSAGE, THERE IS NO GARUNTEE THAT YOU NICK HAS
;                           CHANGED.
; Related .......:
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _IRC_SetNick($iSocket, $sNick)
	_IRC_SendRaw($iSocket, 'NICK ' & $sNick)
	If @error Then Return SetError(1, @extended, False)
	Return True
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _IRC_SetMode
; Description ...: Set a mode on a nick.
; Syntax ........: _IRC_SetMode($iSocket, $sNick, $sOperation, $sModes)
; Parameters ....: $iSocket             - $iSocket from _IRC_Connect.
;                  $sNick               - Nickname to apply the mode.
;                  $sOperation          - $IRC_MODE_ADD or $IRC_MODE_REMOVE.
;                  $sModes              - $sMode(s) (one char = one mode).
;                  $sParameters         - $sParameters if any, Default is "" (No parameters).
; Return values .: Success: True
;                  Failure: False & @extended is set to TCPSend's @error.
; Author ........: Damon Harris (TheDcoder)
; Modified ......:
; Remarks .......:
; Related .......:
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _IRC_SetMode($iSocket, $sNick, $sOperation, $sModes, $sParameters = "")
	_IRC_SendRaw($iSocket, 'MODE ' & $sNick & ' ' & $sOperation & $sModes & (($sParameters = "") ? ("") : (' ' & $sParameters)))
	If @error Then Return SetError(1, @extended, False)
	Return True
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _IRC_SetTopic
; Description ...: Set the topic of a channel.
; Syntax ........: _IRC_SetTopic($iSocket, $sChannel, $sTopic)
; Parameters ....: $iSocket             - $iSocket from _IRC_Connect.
;                  $sChannel            - $sChannel to set the topic.
;                  $sTopic              - The $sTopic to set, use "" to unset topic.
; Return values .: Success: True
;                  Failure: False & @extended is set to TCPSend's @error.
; Author ........: Damon Harris (TheDcoder)
; Modified ......:
; Remarks .......:
; Related .......:
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _IRC_SetTopic($iSocket, $sChannel, $sTopic)
	_IRC_SendRaw($iSocket, 'TOPIC ' & $sChannel & ' :' & $sTopic)
	If @error Then Return SetError(1, @extended, False)
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _IRC_SetUser
; Description ...: Sends the required details of the client to the server.
; Syntax ........: _IRC_SetUser($iSocket, $sUsername, $sRealname, $sMode, $sUnused)
; Parameters ....: $iSocket             - $iSocket from _IRC_Connect.
;                  $sUsername           - Your $sUsername.
;                  $sRealname           - Your $sRealname.
;                  $sMode               - ???. Default is '0'.
;                  $sUnused             - ???. Default is '*'.
; Return values .: Success: True
;                  Failure: False & @extended is set to TCPSend's @error.
; Author ........: Damon Harris (TheDcoder)
; Modified ......:
; Remarks .......: You can safely ignore the last 2 parameters.
; Related .......:
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _IRC_SetUser($iSocket, $sUsername, $sRealname, $sMode = '0', $sUnused = '*')
	_IRC_SendRaw($iSocket, 'USER ' & $sUsername & ' ' & $sMode & ' ' & $sUnused & ' :' & $sRealname)
	If @error Then Return SetError(1, @extended, False)
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _IRC_WaitForNextMsg
; Description ...: Waits until a message arrives from the IRC Server.
; Syntax ........: _IRC_WaitForNextMsg($iSocket, $bFormat = False)
; Parameters ....: $iSocket             - $iSocket from _IRC_Connect.
;                  $bFormat             - If True then the received message is formatted using _IRC_FormatMessage.
; Return values .: Success: The message received.
;                  Failure: Empty string & @extended is set to TCPRecv's @error
; Author ........: Damon Harris (TheDcoder)
; Modified ......:
; Remarks .......:
; Related .......:
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _IRC_WaitForNextMsg($iSocket, $bFormat = False)
	Local $vMessage
	Do
		$vMessage = _IRC_ReceiveRaw($iSocket)
		If @error Then SetError(1, @extended, '')
		Sleep(10)
	Until Not $vMessage = ''
	If $bFormat Then $vMessage = _IRC_FormatMessage($vMessage)
	Return $vMessage
EndFunc

Func __IRC_Base64_Encode($vData)
    $vData = Binary($vData)
    Local $tByteStruct = DllStructCreate("byte[" & BinaryLen($vData) & "]")
    DllStructSetData($tByteStruct, 1, $vData)
    Local $tIntStruct = DllStructCreate("int")
    Local $aDllCall = DllCall("Crypt32.dll", "int", "CryptBinaryToString", _
            "ptr", DllStructGetPtr($tByteStruct), _
            "int", DllStructGetSize($tByteStruct), _
            "int", 1, _
            "ptr", 0, _
            "ptr", DllStructGetPtr($tIntStruct))
    If @error Or Not $aDllCall[0] Then
        Return SetError(1, 0, False) ; error calculating the length of the buffer needed
    EndIf
    Local $tCharStruct = DllStructCreate("char[" & DllStructGetData($tIntStruct, 1) & "]")
    $aDllCall = DllCall("Crypt32.dll", "int", "CryptBinaryToString", _
            "ptr", DllStructGetPtr($tByteStruct), _
            "int", DllStructGetSize($tByteStruct), _
            "int", 1, _
            "ptr", DllStructGetPtr($tCharStruct), _
            "ptr", DllStructGetPtr($tIntStruct))
    If @error Or Not $aDllCall[0] Then
        Return SetError(2, 0, False) ; error encoding
    EndIf
    Return DllStructGetData($tCharStruct, 1)
EndFunc ; https://www.autoitscript.com/forum/topic/139260-autoit-snippets/?do=findComment&comment=1304262

Func __IRC_DefaultLog($sMessage, $bOutgoing)
	Local Static $sFilePath = ""
	Local Static $hFileHandle
	Local $sTimestamp = '[' & @HOUR & ':' & @MIN & ':' & @SEC & ']'
	Local $sDirection = ""
	If $bOutgoing Then
		$sDirection = '>>>'
	Else
		$sDirection = '<<<'
	EndIf
	Local Const $FILE = @ScriptDir & '\IRC Logs\' & @YEAR & '\' & @MON & '\' & @MDAY & '.log'
	If Not $sFilePath = $FILE Then
		$sFilePath = $FILE
		FileClose($hFileHandle)
		$hFileHandle = FileOpen($sFilePath, $FO_APPEND + $FO_BINARY + $FO_CREATEPATH)
	EndIf
	Local $sData = $sTimestamp & ' ' & $sDirection & ' ' & $sMessage
	FileWrite($hFileHandle, $sData)
	ConsoleWrite($sData)
	Return True
EndFunc