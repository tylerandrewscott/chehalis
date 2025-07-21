// scrape_indiana.js

var webPage = require('webpage');
var page = webPage.create();

var fs = require('fs');
var path = 'indiana.html'

page.open("https://secure.in.gov/apps/idoa/contractsearch/", function (status) {
  var content = page.content;
  fs.write(path,content,'w')
  phantom.exit();
});
