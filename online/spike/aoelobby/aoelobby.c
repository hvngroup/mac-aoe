/* aoelobby: launch a DirectPlay game straight into a hosted or joined session
 * through the DirectPlay lobby (IDirectPlayLobby::RunApplication), the way
 * the MSN Gaming Zone did. Runs natively on Windows and under Wine on macOS.
 *
 *   aoelobby host --name A --session "Phong 1" --session-guid {GUID} [--max 8]
 *   aoelobby join --name B --host 10.77.0.11 --session-guid {GUID}
 *   options: --app-guid {GUID}   application to launch (default: AoE RoR)
 *            --wait SECONDS      relay lobby messages from the game until it
 *                                exits or the time runs out (default 0)
 *
 * Every event is printed as one JSON object per line on stdout, so the
 * desktop app can follow the launch. Exit code 0 on success.
 *
 * Build: i686-w64-mingw32-gcc -O2 -o aoelobby.exe aoelobby.c -ldplayx -ldxguid -lole32 -luuid
 */
#define INITGUID
#include <windows.h>
#include <objbase.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dplay.h>
#include <dplobby.h>

/* Age of Empires Expansion (Rise of Rome), as registered by the game's
 * setupreg.exe under DirectPlay\Applications. */
DEFINE_GUID( GUID_AOE_ROR, 0x8701c5c1, 0x337b, 0x11d2, 0x83, 0x9b, 0x00, 0x60, 0x97, 0x07, 0xf5, 0x08 );

static void json_event( const char *event, const char *key, const char *value, long hr )
{
    printf( "{\"event\":\"%s\"", event );
    if ( key ) printf( ",\"%s\":\"%s\"", key, value ? value : "" );
    if ( hr ) printf( ",\"hr\":\"0x%08lx\"", (unsigned long)hr );
    printf( "}\n" );
    fflush( stdout );
}

static int fail( const char *what, HRESULT hr )
{
    json_event( "error", "step", what, hr );
    return 1;
}

static BOOL parse_guid( const char *text, GUID *guid )
{
    WCHAR wide[ 64 ];
    if ( !MultiByteToWideChar( CP_ACP, 0, text, -1, wide, 64 ) ) return FALSE;
    return SUCCEEDED( CLSIDFromString( wide, guid ) );
}

static void usage( void )
{
    fprintf( stderr,
             "usage: aoelobby host|join --name NAME --session-guid {GUID} [--session NAME]\n"
             "                [--host IP] [--max N] [--app-guid {GUID}] [--wait SECONDS]\n" );
}

int main( int argc, char **argv )
{
    const char *role, *name = NULL, *session = "HVN AOE", *host = NULL;
    const char *session_guid = NULL, *app_guid = NULL;
    DWORD max_players = 8, wait_seconds = 0, app_id = 0, address_size = 0;
    DPCOMPOUNDADDRESSELEMENT elements[ 2 ];
    IDirectPlayLobbyA *lobby1 = NULL;
    IDirectPlayLobby2A *lobby = NULL;
    DPSESSIONDESC2 desc;
    DPLCONNECTION conn;
    DPNAME player;
    HANDLE event;
    void *address;
    HRESULT hr;
    int i;

    if ( argc < 2 || ( strcmp( argv[ 1 ], "host" ) && strcmp( argv[ 1 ], "join" ) ) )
    {
        usage();
        return 2;
    }
    role = argv[ 1 ];
    for ( i = 2; i + 1 < argc; i += 2 )
    {
        if ( !strcmp( argv[ i ], "--name" ) ) name = argv[ i + 1 ];
        else if ( !strcmp( argv[ i ], "--session" ) ) session = argv[ i + 1 ];
        else if ( !strcmp( argv[ i ], "--session-guid" ) ) session_guid = argv[ i + 1 ];
        else if ( !strcmp( argv[ i ], "--host" ) ) host = argv[ i + 1 ];
        else if ( !strcmp( argv[ i ], "--max" ) ) max_players = (DWORD)atoi( argv[ i + 1 ] );
        else if ( !strcmp( argv[ i ], "--app-guid" ) ) app_guid = argv[ i + 1 ];
        else if ( !strcmp( argv[ i ], "--wait" ) ) wait_seconds = (DWORD)atoi( argv[ i + 1 ] );
        else { usage(); return 2; }
    }
    if ( i != argc || !name || !session_guid || ( !strcmp( role, "join" ) && !host ) )
    {
        usage();
        return 2;
    }

    memset( &desc, 0, sizeof( desc ) );
    desc.dwSize = sizeof( desc );
    desc.dwFlags = DPSESSION_KEEPALIVE;
    desc.dwMaxPlayers = max_players;
    desc.lpszSessionNameA = (char *)session;
    if ( !parse_guid( session_guid, &desc.guidInstance ) ) return fail( "parse --session-guid", E_INVALIDARG );
    desc.guidApplication = GUID_AOE_ROR;
    if ( app_guid && !parse_guid( app_guid, &desc.guidApplication ) ) return fail( "parse --app-guid", E_INVALIDARG );

    hr = DirectPlayLobbyCreateA( NULL, &lobby1, NULL, NULL, 0 );
    if ( FAILED( hr ) ) return fail( "DirectPlayLobbyCreate", hr );
    hr = IDirectPlayLobby_QueryInterface( lobby1, &IID_IDirectPlayLobby2A, (void **)&lobby );
    if ( FAILED( hr ) ) return fail( "QueryInterface(IDirectPlayLobby2A)", hr );

    /* TCP/IP service provider; a joiner also names the host's (virtual) IP so
     * DirectPlay connects to it directly instead of broadcasting. */
    elements[ 0 ].guidDataType = DPAID_ServiceProvider;
    elements[ 0 ].dwDataSize = sizeof( GUID );
    elements[ 0 ].lpData = (void *)&DPSPGUID_TCPIP;
    elements[ 1 ].guidDataType = DPAID_INet;
    elements[ 1 ].dwDataSize = host ? (DWORD)strlen( host ) + 1 : 1;
    elements[ 1 ].lpData = (void *)( host ? host : "" );
    hr = IDirectPlayLobby_CreateCompoundAddress( lobby, elements, 2, NULL, &address_size );
    if ( hr != DPERR_BUFFERTOOSMALL ) return fail( "CreateCompoundAddress(size)", hr );
    address = malloc( address_size );
    hr = IDirectPlayLobby_CreateCompoundAddress( lobby, elements, 2, address, &address_size );
    if ( FAILED( hr ) ) return fail( "CreateCompoundAddress", hr );

    memset( &player, 0, sizeof( player ) );
    player.dwSize = sizeof( player );
    player.lpszShortNameA = (char *)name;
    player.lpszLongNameA = (char *)name;

    memset( &conn, 0, sizeof( conn ) );
    conn.dwSize = sizeof( conn );
    conn.dwFlags = strcmp( role, "host" ) ? DPLCONNECTION_JOINSESSION : DPLCONNECTION_CREATESESSION;
    conn.lpSessionDesc = &desc;
    conn.lpPlayerName = &player;
    conn.guidSP = DPSPGUID_TCPIP;
    conn.lpAddress = address;
    conn.dwAddressSize = address_size;

    event = CreateEventA( NULL, FALSE, FALSE, NULL );
    hr = IDirectPlayLobby_RunApplication( lobby, 0, &app_id, &conn, event );
    if ( FAILED( hr ) ) return fail( "RunApplication", hr );
    json_event( "launched", "role", role, 0 );

    /* Relay what the game tells its lobby (results, status) until it exits. */
    if ( wait_seconds )
    {
        DWORD deadline = GetTickCount() + wait_seconds * 1000;
        BYTE buffer[ 4096 ];
        while ( (LONG)( deadline - GetTickCount() ) > 0 )
        {
            DWORD flags = 0, size = sizeof( buffer ) - 1;
            WaitForSingleObject( event, 250 );
            hr = IDirectPlayLobby_ReceiveLobbyMessage( lobby, 0, app_id, &flags, buffer, &size );
            if ( hr == DPERR_NOMESSAGES ) continue;
            if ( FAILED( hr ) ) { json_event( "receive_failed", NULL, NULL, hr ); break; }
            if ( flags & DPLMSG_SYSTEM )
            {
                DWORD type = ( (DPLMSG_GENERIC *)buffer )->dwType;
                char text[ 16 ];
                sprintf( text, "0x%08lx", (unsigned long)type );
                json_event( "system_message", "type", text, 0 );
                if ( type == DPLSYS_APPTERMINATED ) break;
            }
            else
            {
                buffer[ size ] = 0;
                json_event( "app_message", "data", (char *)buffer, 0 );
            }
        }
    }

    json_event( "done", "role", role, 0 );
    free( address );
    IDirectPlayLobby_Release( lobby );
    IDirectPlayLobby_Release( lobby1 );
    return 0;
}
