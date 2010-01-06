/* Ruxtape */
$(document).ready(function(){
    $("#warning").hide(); // shows a warning if javascript isn't enabled

    function signature(){
        if ($("#signature").length > 0) {
            return "&signed="+$("#signature").text();
        } else {
            return "";
        }
    }

    if ($("#sorter").length > 0) {
        $("#sorter").sortable({
            axis: 'y',
            stop: function(e,ui){
                $.post("/admin/reorder", 
                       $("#sorter").sortable("serialize", {expression: /(songs)_(.+)/})+signature()) }});
    }

    $(".edit_song_button").click(function () {
      $(this).parents(".song").children(".edit_song").children(".edit_song_form").toggle('slide');
    });

});