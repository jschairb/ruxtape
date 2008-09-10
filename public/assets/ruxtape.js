/* Ruxtape */
$(document).ready(function(){
    $("#warning").hide(); // shows a warning if javascript isn't enabled
});

$(document).ready(function(){
    if ($("#sorter").length > 0) {
        $("#sorter").sortable({stop: function(e,ui){
            $.post("/admin/reorder", $("#sorter").sortable("serialize")+"&signed="+$("#signature").text()) 
        }});
    }
});

function signature(){
    if ($("#signature").length > 0) {
        return "&signed="+$("#signature").text();
    } else {
        return "";
    }
}