// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults
<!--
  numImmag = 1
  path = "/images/clock/";
  // Carica in anticipo le immagini
  immagini = new Array()
  for(i = 0; i < 10; i++) 
  {
    immagini[i] = new Image()
    immagini[i].src = path + i + ".gif"
  }

  function scriviora()
  {
    oggi = new Date()
    ore = oggi.getHours()
    if (ore < 10)
      ore = "0" + ore + "" // con l'aggiunta di "" converte il valore in stringa
    else
      ore += ""            // converte il valore in stringa; idem per min e sec
    min = oggi.getMinutes()
    if (min < 10)
      min = "0" + min + ""
    else
      min += ""
    sec = oggi.getSeconds()
    if (sec < 10)
      sec = "0" + sec + ""
    else
      sec += ""
    // per selezionare l'immagine del numero da visualizzare, 
    // rileva dalla stringa la cifra con substr(posizione,lunghezza)
    document.ora1.src = immagini[ore.substr(0,1)].src
    document.ora2.src = immagini[ore.substr(1,1)].src
    document.min1.src = immagini[min.substr(0,1)].src
    document.min2.src = immagini[min.substr(1,1)].src
    document.sec1.src = immagini[sec.substr(0,1)].src
    document.sec2.src = immagini[sec.substr(1,1)].src
  }
//-->
