/* Shared helpers for the DirectPlay host/join acceptance tests.
 * Build: i686-w64-mingw32-gcc -O1 -o dphost.exe dphost.c -ldplayx -ldxguid -lole32 -luuid
 */
#ifndef DPTEST_H
#define DPTEST_H

#define INITGUID
#include <windows.h>
#include <objbase.h>
#include <stdio.h>
#include <string.h>
#include <dplay.h>
#include <dplobby.h>

/* {6F1A9C3E-5B2D-4E7A-9C11-2B7D3E4F5A61}  test application GUID */
DEFINE_GUID( GUID_DPTEST_APP, 0x6f1a9c3e, 0x5b2d, 0x4e7a, 0x9c, 0x11, 0x2b, 0x7d, 0x3e, 0x4f, 0x5a, 0x61 );

#define DPTEST_SESSION_NAME "WineHostTest"
#define DPTEST_JOIN_MSG     "hello from joiner"
#define DPTEST_HOST_MSG     "hello from host"
#define DPTEST_UDP_MSG      "unreliable from joiner"

static int failures;

static void check( BOOL ok, const char *what, HRESULT hr )
{
    printf( "%s: %s (hr=0x%08lx)\n", ok ? "PASS" : "FAIL", what, (unsigned long)hr );
    fflush( stdout );
    if ( !ok ) failures++;
}

static const char *dpmsg_type( DWORD type )
{
    switch ( type )
    {
    case DPSYS_CREATEPLAYERORGROUP:  return "DPSYS_CREATEPLAYERORGROUP";
    case DPSYS_DESTROYPLAYERORGROUP: return "DPSYS_DESTROYPLAYERORGROUP";
    case DPSYS_ADDPLAYERTOGROUP:     return "DPSYS_ADDPLAYERTOGROUP";
    case DPSYS_SESSIONLOST:          return "DPSYS_SESSIONLOST";
    case DPSYS_HOST:                 return "DPSYS_HOST";
    case DPSYS_SETPLAYERORGROUPDATA: return "DPSYS_SETPLAYERORGROUPDATA";
    case DPSYS_SETPLAYERORGROUPNAME: return "DPSYS_SETPLAYERORGROUPNAME";
    default:                         return "DPSYS_other";
    }
}

/* Create IDirectPlay4A and initialize it with the TCP/IP service provider.
 * ip may be "" (host / broadcast) or a dotted address. */
static HRESULT dptest_init( IDirectPlay4A **dp, const char *ip )
{
    DPCOMPOUNDADDRESSELEMENT elems[ 2 ];
    IDirectPlayLobby3A *lobby = NULL;
    DWORD size = 0;
    void *addr;
    HRESULT hr;

    IDirectPlay *dp1 = NULL;
    IDirectPlayLobbyA *lobby1 = NULL;

    /* Use the dplayx exports rather than CoCreateInstance so that the dplayx.dll next to the
     * executable is used instead of the one registered in the prefix. */
    GUID null_guid = { 0 };

    hr = DirectPlayCreate( &null_guid, &dp1, NULL );
    check( SUCCEEDED( hr ), "DirectPlayCreate", hr );
    if ( FAILED( hr ) ) return hr;
    hr = IDirectPlay_QueryInterface( dp1, &IID_IDirectPlay4A, (void **)dp );
    check( SUCCEEDED( hr ), "QueryInterface(IID_IDirectPlay4A)", hr );
    IDirectPlay_Release( dp1 );
    if ( FAILED( hr ) ) return hr;

    hr = DirectPlayLobbyCreateA( NULL, &lobby1, NULL, NULL, 0 );
    check( SUCCEEDED( hr ), "DirectPlayLobbyCreateA", hr );
    if ( FAILED( hr ) ) return hr;
    hr = IDirectPlayLobby_QueryInterface( lobby1, &IID_IDirectPlayLobby3A, (void **)&lobby );
    IDirectPlayLobby_Release( lobby1 );
    check( SUCCEEDED( hr ), "QueryInterface(IID_IDirectPlayLobby3A)", hr );
    if ( FAILED( hr ) ) return hr;

    elems[ 0 ].guidDataType = DPAID_ServiceProvider;
    elems[ 0 ].dwDataSize = sizeof( GUID );
    elems[ 0 ].lpData = (void *)&DPSPGUID_TCPIP;
    elems[ 1 ].guidDataType = DPAID_INet;
    elems[ 1 ].dwDataSize = strlen( ip ) + 1;
    elems[ 1 ].lpData = (void *)ip;

    hr = IDirectPlayLobby_CreateCompoundAddress( lobby, elems, 2, NULL, &size );
    addr = HeapAlloc( GetProcessHeap(), 0, size );
    hr = IDirectPlayLobby_CreateCompoundAddress( lobby, elems, 2, addr, &size );
    check( SUCCEEDED( hr ), "CreateCompoundAddress(TCP/IP)", hr );
    IDirectPlayLobby_Release( lobby );
    if ( FAILED( hr ) ) return hr;

    hr = IDirectPlayX_InitializeConnection( *dp, addr, 0 );
    check( SUCCEEDED( hr ), "InitializeConnection(TCP/IP)", hr );
    HeapFree( GetProcessHeap(), 0, addr );
    return hr;
}

#endif
