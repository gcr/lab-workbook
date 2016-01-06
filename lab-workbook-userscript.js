// ==UserScript==
// @name         Lab Workbook for Trello
// @namespace    http://tampermonkey.net/
// @version      0.1
// @description  dump results into S3, stream progress to Trello
// @author       You
// @match        https://trello.com/*
// @grant        GM_xmlhttpRequest
// @grant        unsafeWindow
// ==/UserScript==
/* jshint -W097 */
'use strict';

function inheritsFrom(child, parent) {
  child.prototype = Object.create(parent.prototype);
}


function workbookInject(){
  // Step 1: Add injection handler
  unsafeWindow.TFM.description.parseInlineOutput.link = maybeInsertLink(
    unsafeWindow.TFM.description.parseInlineOutput.link);
  // Step 2: Add Dygraph library for interactive graphing :)
  var dygraph = document.createElement('script');
  dygraph.setAttribute("src", "//cdnjs.cloudflare.com/ajax/libs/dygraph/1.1.1/dygraph-combined.js");
  document.head.appendChild(dygraph);
}

function maybeInsertLink(oldLinkHandler) {
  return function(link){
    if (/WORKBOOK_IMAGE/.exec(link.url)) {
      console.log("Creating image...");
      var element = new WorkbookAutomaticImage(link.url);
      return this.html.apply(this, element.createNewElement());
    } else if (/WORKBOOK_PLOT/.exec(link.url)) {
      console.log("Creating plot...");
      var element = new WorkbookAutomaticPlot(link.url);
      return this.html.apply(this, element.createNewElement());
    } else {
      return oldLinkHandler.call(this, link);
    }
  };
}

function WorkbookAutomaticElement(url) {
  this.url = url;
}
WorkbookAutomaticElement.prototype.createNewElement = function(){
  // Call me when rendering
  // Does several things:
  // - Returns the HTML element placeholder for you to fill :)
  // - Registers a callback to populate `this.element` when it has
  //   been rendered by Trello.
  var self = this;
  this.document_id = "workbook-";
  for (var i=0; i<10; i++) {
    this.document_id += "0123456789abcdef"[Math.floor(Math.random()*16)];
  }
  unsafeWindow.requestAnimationFrame(function(){
                                 // Assign javascript to this element
                                 self.element = document.getElementById(self.document_id);
                                 self.onBound();
                               });
  return this.html();
};
WorkbookAutomaticElement.prototype.html = function(){
  return ["div", "", {attrs: {id: this.document_id}}];
};
WorkbookAutomaticElement.prototype.onBound = function(){};

///////////// Image support /////////////
function WorkbookAutomaticImage(){
  WorkbookAutomaticElement.apply(this, arguments);
}
inheritsFrom(WorkbookAutomaticImage, WorkbookAutomaticElement);
WorkbookAutomaticImage.prototype.onBound = function(){
  $("<img>").attr({src: this.url}).appendTo(this.element);
};

///////////// Plot support /////////////
function WorkbookAutomaticPlot(){
  WorkbookAutomaticElement.apply(this, arguments);
}
inheritsFrom(WorkbookAutomaticPlot, WorkbookAutomaticElement);
WorkbookAutomaticPlot.prototype.onBound = function(){
  var self = this;
  GM_xmlhttpRequest({method: "GET",
                     url: this.url,
                     onload: function(xhr){
                       $(self.element).on('click', function(e){console.log("CLICKY");return e.stopPropagation();});
                       var options = $.parseJSON(xhr.responseText);
                       console.log(options);
                       self.graph = new Dygraph(self.element, options.file, options);
                     }
                    });
};





workbookInject();