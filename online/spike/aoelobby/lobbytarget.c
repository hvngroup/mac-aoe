/* lobbytarget: stand-in for the game in aoelobby tests. When the lobby
 * launches it, it reads the connection settings, writes them as key=value
 * lines to the file named by its first argument, sends one lobby message
 * back (as a game would report a result), and exits.
 *
 * Build: i686-w64-mingw32-gcc -O2 -o lobbytarget.exe lobbytarget.c -ldplayx -ldxguid -lole32 -luuid
 */
#define INITGUID
#include <windows.h>
#include <objbase.h>
#include <stdio.h>
#include <string.h>
#include <dplay.h>
#include <dplobby.h>

static FILE *out;

static BOOL WINAPI on_address_part( REFGUID type, DWORD size, const void *data, void *context )
{
    if ( IsEqualGUID( type, &DPAID_INet ) )
        fprintf( out, "inet=%.*s\n", (int)size, (const char *)data );
    else if ( IsEqualGUID( type, &DPAID_ServiceProvider ) )
        fprintf( out, "sp_tcpip=%d\n", IsEqualGUID( (const GUID *)data, &DPSPGUID_TCPIP ) );
    return TRUE;
}

int main( int argc, char **argv )
{
    IDirectPlayLobbyA *lobby;
    BYTE buffer[ 4096 ];
    DPLCONNECTION *conn = (DPLCONNECTION *)buffer;
    DWORD size = sizeof( buffer );
    WCHAR guid_text[ 64 ];
    const char *result = "result:winner=1";
    HRESULT hr;

    out = fopen( argc > 1 ? argv[ 1 ] : "lobbytarget.out", "w" );
    if ( !out ) return 1;

    hr = DirectPlayLobbyCreateA( NULL, &lobby, NULL, NULL, 0 );
    fprintf( out, "create=0x%08lx\n", (unsigned long)hr );
    if ( FAILED( hr ) ) { fclose( out ); return 1; }

    hr = IDirectPlayLobby_GetConnectionSettings( lobby, 0, conn, &size );
    fprintf( out, "get_connection_settings=0x%08lx\n", (unsigned long)hr );
    if ( SUCCEEDED( hr ) )
    {
        fprintf( out, "create_session=%d\n", !!( conn->dwFlags & DPLCONNECTION_CREATESESSION ) );
        fprintf( out, "join_session=%d\n", !!( conn->dwFlags & DPLCONNECTION_JOINSESSION ) );
        fprintf( out, "session_name=%s\n", conn->lpSessionDesc->lpszSessionNameA );
        fprintf( out, "max_players=%lu\n", (unsigned long)conn->lpSessionDesc->dwMaxPlayers );
        StringFromGUID2( &conn->lpSessionDesc->guidInstance, guid_text, 64 );
        fprintf( out, "session_guid=%ls\n", guid_text );
        fprintf( out, "player_name=%s\n", conn->lpPlayerName->lpszShortNameA );
        IDirectPlayLobby_EnumAddress( lobby, on_address_part, conn->lpAddress, conn->dwAddressSize, NULL );
    }

    hr = IDirectPlayLobby_SendLobbyMessage( lobby, 0, 0, (void *)result, (DWORD)strlen( result ) );
    fprintf( out, "send_lobby_message=0x%08lx\n", (unsigned long)hr );
    fclose( out );
    IDirectPlayLobby_Release( lobby );
    Sleep( 500 );
    return 0;
}
