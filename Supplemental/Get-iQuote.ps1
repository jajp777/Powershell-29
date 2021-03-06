function Get-iQuote {
    <#
    #Valid Sources
    #From geek: esr humorix_misc humorix_stories joel_on_software macintosh math mav_flame osp_rules paul_graham prog_style subversion
    #From general: 1811_dictionary_of_the_vulgar_tongue codehappy fortune liberty literature misc murphy oneliners riddles rkba shlomif shlomif_fav stephen_wright
    #From pop: calvin forrestgump friends futurama holygrail powerpuff simon_garfunkel simpsons_cbg simpsons_chalkboard simpsons_homer simpsons_ralph south_park starwars xfiles
    #From religious: bible contentions osho
    #From scifi: cryptonomicon discworld dune hitchhiker
    
    # Example
    Get-iQuote -max_lines 2 -source @('esr','math')
    #>

    param (
        [Parameter(Position=0,HelpMessage='return format of quote')]
        [ValidateSet('text','html','json')]
        [string]$format = 'text',
        [Parameter(Position=1,HelpMessage='Maximum number of lines to return')]
        [int]$max_lines,
        [Parameter(Position=2,HelpMessage='Minimum number of lines to return')]
        [int]$min_lines,
        [Parameter(Position=3,HelpMessage='Maximum number of characters to return')]
        [int]$max_characters,
        [Parameter(Position=4,HelpMessage='Minimum number of characters to return')]
        [int]$min_characters,
        [Parameter(Position=5,HelpMessage='One or more quote categories to query.')]
        [ValidateScript({
            $validsources = @('esr','humorix_misc','humorix_stories','joel_on_software','macintosh','math','mav_flame','osp_rules','paul_graham','prog_style','subversion','1811_dictionary_of_the_vulgar_tongue','codehappy','fortune','liberty','literature','misc','murphy','oneliners','riddles','rkba','shlomif','shlomif_fav','stephen_wright','calvin','forrestgump','friends','futurama','holygrail','powerpuff','simon_garfunkel','simpsons_cbg','simpsons_chalkboard','simpsons_homer','simpsons_ralph','south_park','starwars','xfiles','bible','contentions','osho','cryptonomicon','discworld','dune','hitchhiker')
            if ((Compare-Object -ReferenceObject $validsources -DifferenceObject $_).SideIndicator -contains '=>') {
                $false
            }
            else {
                $true
            }
        })]
        [string[]]$source = @('esr','humorix_misc','humorix_stories','joel_on_software','macintosh','math','mav_flame','osp_rules','paul_graham','prog_style','subversion','1811_dictionary_of_the_vulgar_tongue','codehappy','fortune','liberty','literature','misc','murphy','oneliners','riddles','rkba','shlomif','shlomif_fav','stephen_wright','calvin','forrestgump','friends','futurama','holygrail','powerpuff','simon_garfunkel','simpsons_cbg','simpsons_chalkboard','simpsons_homer','simpsons_ralph','south_park','starwars','xfiles','bible','contentions','osho','cryptonomicon','discworld','dune','hitchhiker')
    )
    $req_uri = 'http://www.iheartquotes.com/api/v1/random?format=' + $format 
    $PSBoundParameters.Keys | Foreach {
        if ($_ -ne 'format') {
            $req_uri += '&' + $_ + '=' + ($PSBoundParameters[$_] -join '+')
        }
    }

    $sources = ($source | % { [regex]::escape($_) } ) -join '|'
    $sourceregex = '(?m)^([^\[]*)(?:\[(' + $sources + ')\].+)$'
    
    $quote = (Invoke-WebRequest -Uri $req_uri).content

    ((([regex]::Match($quote,$sourceregex)).Groups)[1]).Value -replace '&quot;','"'
}