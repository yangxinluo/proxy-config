BeforeAll {
    $script:Root = Resolve-Path (Join-Path $PSScriptRoot '../..')
    . (Join-Path $script:Root 'bin/proxy.ps1')
}

Describe 'Read-ClashProxyConfig' {
    It 'loads defaults from config.defaults.env' {
        $config = Read-ClashProxyConfig -Root $script:Root
        $config.HTTP_PORT | Should -Be '7890'
        $config.NO_PROXY | Should -Match '192.168.0.0/16'
        $config.GIT_PROXY_SCHEME | Should -Be 'http'
    }
}

Describe 'Test-ClashProxyConfig' {
    It 'rejects invalid host' {
        $bad = @{
            HOST       = 'bad host'
            HTTP_PORT  = '7890'
            SOCKS_PORT = '7891'
        }
        { Test-ClashProxyConfig -Config $bad } | Should -Throw '*invalid HOST*'
    }

    It 'rejects invalid port' {
        $bad = @{
            HOST       = ''
            HTTP_PORT  = 'abc'
            SOCKS_PORT = '7891'
        }
        { Test-ClashProxyConfig -Config $bad } | Should -Throw '*invalid HTTP_PORT*'
    }
}

Describe 'Get-GitProxyUrl' {
    It 'returns http url by default' {
        $config = @{ GIT_PROXY_SCHEME = 'http' }
        $url = Get-GitProxyUrl -Config $config -HttpUrl 'http://127.0.0.1:7890' -SocksUrl 'socks5://127.0.0.1:7891'
        $url | Should -Be 'http://127.0.0.1:7890'
    }

    It 'returns socks url when scheme is socks5' {
        $config = @{ GIT_PROXY_SCHEME = 'socks5' }
        $url = Get-GitProxyUrl -Config $config -HttpUrl 'http://127.0.0.1:7890' -SocksUrl 'socks5://127.0.0.1:7891'
        $url | Should -Be 'socks5://127.0.0.1:7891'
    }
}

Describe 'Get-ClashProxyHost' {
    It 'returns forced HOST from config' {
        $config = @{ HOST = '10.0.0.5' }
        Get-ClashProxyHost -Config $config | Should -Be '10.0.0.5'
    }

    It 'defaults to 127.0.0.1 when HOST empty' {
        $config = @{ HOST = '' }
        Get-ClashProxyHost -Config $config | Should -Be '127.0.0.1'
    }
}

Describe 'Get-ClashProxyVersion' {
    It 'reads VERSION file' {
        Get-ClashProxyVersion | Should -Match '^\d+\.\d+\.\d+$'
    }
}
