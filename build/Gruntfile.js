module.exports = function(grunt) {

	require('jit-grunt')(grunt);

	var mainFolder = "main/";
	var siteFolder = "site/"
	var siteBasename = "index.html";

	var sourceFolder = "../src/";

	var sourceMainFolder = sourceFolder + mainFolder;
	var elmSources = [ sourceMainFolder + "**/*.elm" ];

	var sourceSiteFolder = sourceFolder + "site/";
	var siteScripts = [ sourceSiteFolder + "**/*.ts" ];
	var stylesheets = [ sourceSiteFolder + "**/*.less" ];
	var site = sourceSiteFolder + siteBasename;

	var targetFolder = "../target/";
	var compiledScriptsBasename = "scripts.js";

	var targetSiteFolder = targetFolder + siteFolder;
	var compiledDependenciesBasename = "bower_components.js";
	var compiledDependencies = targetSiteFolder + compiledDependenciesBasename;
	var compiledElmBasename = "elm.js";
	var compiledElm = targetSiteFolder + compiledElmBasename;
	var compiledSiteScripts = targetSiteFolder + compiledScriptsBasename;
	var compiledStylesheetsBasename = "stylesheets.css";
	var compiledStylesheets = targetSiteFolder + compiledStylesheetsBasename;
	var compiledSite = targetSiteFolder + siteBasename;

	grunt.initConfig({
		watch : {
			elm : {
				files : elmSources,
				tasks : [ "elm" ]
			},
			bower_concat : {
				files : [ "bower.json" ],
				tasks : [ "bower_concat" ]
			},
			typescript_site : {
				files : siteScripts,
				tasks : [ "typescript:site" ]
			},
			less : {
				files : stylesheets,
				tasks : [ "less" ]
			},
			site : {
				files : site,
				tasks : [ "dom_munger" ]
			},
		},
		elm : {
			compile : {
				files : [
					{
						src : elmSources,
						dest : compiledElm
					}
				],
				options : {
					yesToAllPrompts : true
				}
			}
		},
		bower_concat : {
			build : {
				dest : compiledDependencies
			}
		},
		typescript : {
			site : {
				src : siteScripts,
				dest : compiledSiteScripts
			}
		},
		less : {
			build : {
				src : stylesheets,
				dest : compiledStylesheets
			}
		},
		dom_munger : {
			build : {
				src : site,
				dest : compiledSite,
				options : {
					append : {
						selector : "head",
						html :
							'<script src="' + compiledElmBasename + '" type="text/javascript"></script>' +
							'<script src="' + compiledDependenciesBasename + '" type="text/javascript"></script>' +
							'<script src="' + compiledScriptsBasename + '" type="text/javascript"></script>' +
							'<link rel="stylesheet" href="' + compiledStylesheetsBasename + '" type="text/css" />'
					}
				}
			}
		},
		open : {
			build : {
				path : compiledSite
			}
		}
	});

};