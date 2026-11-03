/* dphost: create a DirectPlay TCP/IP session and wait for a joiner.
 * Usage: dphost.exe [seconds]   (default 40)
 * Exit code: number of failed checks.
 */
#include "dptest.h"

static BOOL CALLBACK enum_players_cb( DPID id, DWORD type, const DPNAME *name, DWORD flags,
                                      void *ctx )
{
    printf( "INFO: player 0x%08lx name=%s flags=0x%lx\n", (unsigned long)id,
            name && name->lpszShortNameA ? name->lpszShortNameA : "(null)",
            (unsigned long)flags );
    (*(int *)ctx)++;
    return TRUE;
}

int main( int argc, char **argv )
{
    int seconds = argc > 1 ? atoi( argv[ 1 ] ) : 40;
    BOOL got_join = FALSE, got_reliable = FALSE, got_unreliable = FALSE, got_bye = FALSE;
    DPSESSIONDESC2 sd;
    IDirectPlay4A *dp;
    DPNAME name;
    DPID host_player;
    DWORD start;
    HRESULT hr;
    int count;

    setvbuf( stdout, NULL, _IONBF, 0 );
    CoInitialize( NULL );

    if ( FAILED( dptest_init( &dp, "" ) ) )
        return 1;

    memset( &sd, 0, sizeof( sd ) );
    sd.dwSize = sizeof( sd );
    sd.dwFlags = 0;
    sd.guidApplication = GUID_DPTEST_APP;
    sd.dwMaxPlayers = 8;
    sd.lpszSessionNameA = (char *)DPTEST_SESSION_NAME;
    hr = IDirectPlayX_Open( dp, &sd, DPOPEN_CREATE );
    check( SUCCEEDED( hr ), "host Open(DPOPEN_CREATE)", hr );
    if ( FAILED( hr ) )
        return failures;

    memset( &name, 0, sizeof( name ) );
    name.dwSize = sizeof( name );
    name.lpszShortNameA = (char *)"HostPlayer";
    hr = IDirectPlayX_CreatePlayer( dp, &host_player, &name, NULL, NULL, 0, 0 );
    check( SUCCEEDED( hr ), "host CreatePlayer(HostPlayer)", hr );
    printf( "INFO: host player id 0x%08lx\n", (unsigned long)host_player );
    printf( "READY\n" );

    start = GetTickCount();
    while ( GetTickCount() - start < (DWORD)seconds * 1000 && !got_bye )
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
            check( FALSE, "host Receive", hr );
            break;
        }

        if ( from == DPID_SYSMSG )
        {
            DPMSG_GENERIC *msg = (DPMSG_GENERIC *)buf;
            printf( "INFO: host got system message %s (0x%lx)\n", dpmsg_type( msg->dwType ),
                    (unsigned long)msg->dwType );
            if ( msg->dwType == DPSYS_CREATEPLAYERORGROUP )
            {
                DPMSG_CREATEPLAYERORGROUP *cp = (DPMSG_CREATEPLAYERORGROUP *)buf;
                printf( "INFO:   new player 0x%08lx name=%s\n", (unsigned long)cp->dpId,
                        cp->dpnName.lpszShortNameA ? cp->dpnName.lpszShortNameA : "(null)" );
                if ( !got_join )
                    check( TRUE, "host saw remote player join (DPSYS_CREATEPLAYERORGROUP)", hr );
                got_join = TRUE;
            }
            continue;
        }

        buf[ size < sizeof( buf ) ? size : sizeof( buf ) - 1 ] = 0;
        printf( "INFO: host got app message from 0x%08lx to 0x%08lx: \"%s\"\n",
                (unsigned long)from, (unsigned long)to, buf );
        if ( !strcmp( buf, DPTEST_JOIN_MSG ) && !got_reliable )
        {
            got_reliable = TRUE;
            check( TRUE, "host received guaranteed message from joiner", hr );
            hr = IDirectPlayX_Send( dp, host_player, from, DPSEND_GUARANTEED,
                                    (void *)DPTEST_HOST_MSG, sizeof( DPTEST_HOST_MSG ) );
            check( SUCCEEDED( hr ), "host Send(guaranteed) reply to joiner", hr );
        }
        else if ( !strcmp( buf, DPTEST_UDP_MSG ) && !got_unreliable )
        {
            got_unreliable = TRUE;
            check( TRUE, "host received non-guaranteed message from joiner", hr );
        }
        else if ( !strcmp( buf, "bye" ) )
            got_bye = TRUE;
    }

    check( got_join, "host: joiner player created", 0 );
    check( got_reliable, "host: guaranteed message received", 0 );
    check( got_unreliable, "host: non-guaranteed message received", 0 );

    count = 0;
    hr = IDirectPlayX_EnumPlayers( dp, NULL, enum_players_cb, &count, DPENUMPLAYERS_ALL );
    check( SUCCEEDED( hr ) && count >= 2, "host EnumPlayers sees >= 2 players", hr );

    IDirectPlayX_Close( dp );
    IDirectPlayX_Release( dp );
    CoUninitialize();
    printf( "RESULT: host %s (%d failures)\n", failures ? "FAILED" : "OK", failures );
    return failures;
}
