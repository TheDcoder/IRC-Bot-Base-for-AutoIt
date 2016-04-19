#include <MsgBoxConstants.au3>
#include "Config.au3"
#include "IRC.au3"

Opt("TCPTimeout", 1000)

Global $g_iServerSocket
Global $g_aMessage[0]

_Bot_Connect()

_IRC_JoinChannel($g_iServerSocket, $CHANNEL)

While 1
	$g_aMessage = _IRC_WaitForNextMsg($g_iServerSocket)
WEnd

Func _Bot_Connect()
	$g_iServerSocket = _IRC_Connect($SERVER, $PORT)
	If @error Then Exit MsgBox($MB_ICONERROR, "Connection Error", "Failed to connect to the IRC Server! (@error: " & @error & ')')
	_IRC_AuthPlainSASL($g_iServerSocket, $USERNAME, $PASSWORD)
	If @error Then Exit MsgBox($MB_ICONERROR, "Login Failed!", "Failed to login into the IRC Server! (@error: " & @error & ')')
	_IRC_SetUser($g_iServerSocket, $USERNAME, $REALNAME)
	If @error Then Exit MsgBox($MB_ICONERROR, "Error while setting the user!", "An connection error occured during communication with the server! (@error: " & @error & ')')
	_IRC_SetNick($g_iServerSocket, $NICKNAME)
	If @error Then Exit MsgBox($MB_ICONERROR, "Error while setting the nickname!", "An connection error occured during communication with the server! (@error: " & @error & ')')
EndFunc