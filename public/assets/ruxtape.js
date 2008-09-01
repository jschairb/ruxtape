/* Ruxtape */
$(document).ready(function(){
    $("#warning").hide(); // shows a warning if javascript isn't enabled
    $("div#openplayer").flash( {
        src: '/assets/mediaplayer.swf',
        width: 0,
        height: 0,
        allowscriptaccess: "always",
        flashvars: {
            type: "xml",
            shuffle: "false",
            repeat: "list",
            file: "http://localhost:3301/xspf.xml"
        }
        
    });

});