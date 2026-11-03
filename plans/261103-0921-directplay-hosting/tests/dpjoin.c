/* dpjoin: find the dphost session, join it, create a player and exchange messages.
 * Usage: dpjoin.exe [name] [linger-seconds] [ip]
 *   name            player name, default "JoinPlayer"
 *   linger-seconds  keep receiving this long after the exchange with the host, and greet any other
 *                   joiner that shows up (default 0)
 *   ip              address given to the TCP/IP service provider (default "" = broadcast)
 * Exit code: number of failed checks.
 */
#include "dptest.h"

static DPSESSIONDESC2 found;
static BOOL have_session;

static BOOL CALLBACK enum_sessions_cb( const DPSESSIONDESC2 *sd, DWORD *timeout, DWORD flags,
                                       void *ctx )
{
    if ( flags & DPESC_TIMEDOUT )
        return FALSE;
    printf( "INFO: found session \"%s\" players %lu/%lu\n",
            sd->lpszSessionNameA ? sd->lpszSessionNameA : "(null)",
            (unsigned long)sd->dwCurrentPlayers, (unsigned long)sd->dwMaxPlayers );
    if ( sd->lpszSessionNameA && !strcmp( sd->lpszSessionNameA, DPTEST_SESSION_NAME ) )
    {
        found = *sd;
        found.lpszSessionNameA = NULL;
        have_session = TRUE;
    }
    return TRUE;
}

static DPID host_player, peer_player, my_player;

static BOOL CALLBACK enum_players_cb( DPID id, DWORD type, const DPNAME *name, DWORD flags,
                                      void *ctx )
{
    printf( "INFO: player 0x%08lx name=%s flags=0x%lx\n", (unsigned long)id,
            name && name->lpszShortNameA ? name->lpszShortNameA : "(null)",
            (unsigned long)flags );
    if ( name && name->lpszShortNameA && !strcmp( name->lpszShortNameA, "HostPlayer" ) )
        host_player = id;
    else if ( id != my_player )
        peer_player = id;
    return TRUE;
}

#define DPTEST_PEER_MSG "hello peer"

int main( int argc, char **argv )
{
    const char *player_name = argc > 1 ? argv[ 1 ] : "JoinPlayer";
    int linger = argc > 2 ? atoi( argv[ 2 ] ) : 0;
    const char *ip = argc > 3 ? argv[ 3 ] : "";
    BOOL got_reply = FALSE, got_peer = FALSE, sent_peer = FALSE;
    DPSESSIONDESC2 sd;
    IDirectPlay4A *dp;
    DPNAME name;
    DWORD start;
    HRESULT hr = E_FAIL;
    int tries;

    setvbuf( stdout, NULL, _IONBF, 0 );
    CoInitialize( NULL );

    if ( FAILED( dptest_init( &dp, ip ) ) )
        return 1;

    memset( &sd, 0, sizeof( sd ) );
    sd.dwSize = sizeof( sd );
    sd.guidApplication = GUID_DPTEST_APP;
    for ( tries = 0; tries < 3 && !have_session; tries++ )
    {
        hr = IDirectPlayX_EnumSessions( dp, &sd, 2000, enum_sessions_cb, NULL,
                                        DPENUMSESSIONS_AVAILABLE );
        printf( "INFO: EnumSessions try %d hr=0x%08lx\n", tries, (unsigned long)hr );
    }
    check( have_session, "joiner EnumSessions found " DPTEST_SESSION_NAME, hr );
    if ( !have_session )
        return failures;

    hr = IDirectPlayX_Open( dp, &found, DPOPEN_JOIN );
    check( SUCCEEDED( hr ), "joiner Open(DPOPEN_JOIN)", hr );
    if ( FAILED( hr ) )
        return failures;

    memset( &name, 0, sizeof( name ) );
    name.dwSize = sizeof( name );
    name.lpszShortNameA = (char *)player_name;
    hr = IDirectPlayX_CreatePlayer( dp, &my_player, &name, NULL, NULL, 0, 0 );
    check( SUCCEEDED( hr ), "joiner CreatePlayer", hr );
    printf( "INFO: joiner player id 0x%08lx\n", (unsigned long)my_player );

    hr = IDirectPlayX_EnumPlayers( dp, NULL, enum_players_cb, NULL, DPENUMPLAYERS_ALL );
    check( SUCCEEDED( hr ) && host_player, "joiner EnumPlayers sees HostPlayer", hr );
    if ( !host_player )
        return failures;

    hr = IDirectPlayX_Send( dp, my_player, host_player, DPSEND_GUARANTEED,
                            (void *)DPTEST_JOIN_MSG, sizeof( DPTEST_JOIN_MSG ) );
    check( SUCCEEDED( hr ), "joiner Send(guaranteed) to host", hr );

    hr = IDirectPlayX_Send( dp, my_player, host_player, 0,
                            (void *)DPTEST_UDP_MSG, sizeof( DPTEST_UDP_MSG ) );
    check( SUCCEEDED( hr ), "joiner Send(non-guaranteed) to host", hr );

    start = GetTickCount();
    while ( GetTickCount() - start < 10000 && !got_reply )
    {
        char buf[ 1024 ];
        DWORD size = sizeof( buf );
        DPID from = 0, to = 0;

        hr = IDirectPlayX_Receive( dp, &from, &to, DPRECEIVE_ALL, buf, &size );
        if ( hr == DPERR_NOMESSAGES )
        {
            Sleep( 20 );
            continue;
        }
        if ( FAILED( hr ) )
        {
            check( FALSE, "joiner Receive", hr );
            break;
        }
        if ( from == DPID_SYSMSG )
        {
            printf( "INFO: joiner got system message %s\n",
                    dpmsg_type( ((DPMSG_GENERIC *)buf)->dwType ) );
            continue;
        }
        buf[ size < sizeof( buf ) ? size : sizeof( buf ) - 1 ] = 0;
        printf( "INFO: joiner got app message from 0x%08lx: \"%s\"\n", (unsigned long)from, buf );
        if ( !strcmp( buf, DPTEST_HOST_MSG ) )
            got_reply = TRUE;
    }
    check( got_reply, "joiner received host reply", 0 );

    if ( peer_player )
    {
        hr = IDirectPlayX_Send( dp, my_player, peer_player, DPSEND_GUARANTEED,
                                (void *)DPTEST_PEER_MSG, sizeof( DPTEST_PEER_MSG ) );
        check( SUCCEEDED( hr ), "joiner Send(guaranteed) to the other joiner", hr );
        sent_peer = TRUE;
    }

    start = GetTickCount();
    while ( GetTickCount() - start < (DWORD)linger * 1000 && !got_peer )
    {
        char buf[ 1024 ];
        DWORD size = sizeof( buf );
        DPID from = 0, to = 0;

        hr = IDirectPlayX_Receive( dp, &from, &to, DPRECEIVE_ALL, buf, &size );
        if ( hr == DPERR_NOMESSAGES )
        {
            Sleep( 20 );
            continue;
        }
        if ( FAILED( hr ) )
            break;
        if ( from == DPID_SYSMSG )
        {
            DPMSG_GENERIC *msg = (DPMSG_GENERIC *)buf;
            printf( "INFO: joiner got system message %s\n", dpmsg_type( msg->dwType ) );
            if ( msg->dwType == DPSYS_CREATEPLAYERORGROUP )
            {
                DPMSG_CREATEPLAYERORGROUP *cp = (DPMSG_CREATEPLAYERORGROUP *)buf;
                printf( "INFO:   new player 0x%08lx name=%s\n", (unsigned long)cp->dpId,
                        cp->dpnName.lpszShortNameA ? cp->dpnName.lpszShortNameA : "(null)" );
                check( TRUE, "joiner saw another joiner arrive", 0 );
            }
            continue;
        }
        buf[ size < sizeof( buf ) ? size : sizeof( buf ) - 1 ] = 0;
        printf( "INFO: joiner got app message from 0x%08lx: \"%s\"\n", (unsigned long)from, buf );
        if ( !strcmp( buf, DPTEST_PEER_MSG ) )
        {
            got_peer = TRUE;
            check( TRUE, "joiner received message from the other joiner", 0 );
        }
    }
    if ( linger && !sent_peer && !got_peer )
        check( FALSE, "joiner received message from the other joiner", 0 );

    /* Give the unreliable datagram a retry in case the first one was dropped. */
    IDirectPlayX_Send( dp, my_player, host_player, 0, (void *)DPTEST_UDP_MSG,
                       sizeof( DPTEST_UDP_MSG ) );
    Sleep( 300 );
    IDirectPlayX_Send( dp, my_player, host_player, DPSEND_GUARANTEED, (void *)"bye", 4 );
    Sleep( 500 );

    IDirectPlayX_Close( dp );
    IDirectPlayX_Release( dp );
    CoUninitialize();
    printf( "RESULT: joiner %s (%d failures)\n", failures ? "FAILED" : "OK", failures );
    return failures;
}
