/* Ruxtape */
$(document).ready(function(){
    $("#warning").hide(); // shows a warning if javascript isn't enabled
    $("div#openplayer").media( {
        flashvars: {
        }
    });

//    var so = new SWFObject("movie.swf", "mymovie", "400", "100%", "8", "#336699");
//    so.aaddParam("quality", "low");
//    so.addParam("wmode", "transparent");
//    so.addParam("salign", "t");
//    so.write("flashcontent");
});