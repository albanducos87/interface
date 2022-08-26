function getConso() {
    console.log($("#select_model").val())
    if ($("#select_model").val() == "" || $("#select_model").val() == "reset") {
      console.log("/reset_info_conso");
      url = "/reset_info_conso";
      window.location.replace(url);
    } else {
      console.log("/get_conso_model/<select_model>");
      url = "/get_conso_model/"+$("#select_model").val();
      window.location.replace(url);
    }
}

let changeActive = (className) => {
    console.log("oui");
    var elems = document.querySelectorAll(".active");
    [].forEach.call(elems, function(el) {
        el.classList.remove("active");
    });
    var e = document.getElementById(className);
    e.className = "active";
}

