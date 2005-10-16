function createRequestObject() {
	if( navigator.appName == "Microsoft Internet Explorer" )
		return new ActiveXObject( "Microsoft.XMLHTTP" );
	return new XMLHttpRequest();
}

var currentRequest = createRequestObject();
currentRequest.open( 'GET', '/command/setup' );
currentRequest.send( null );
currentRequest.onreadystatechange = processQueue;

setInterval( checkQueue, 3000 );

function checkQueue() {
	currentRequest = createRequestObject();
	currentRequest.onreadystatechange = processQueue;
	currentRequest.open( 'GET', '/command/checkActivity' );
	currentRequest.send( null );	
}

function processQueue() {
	if( currentRequest.readyState == 4 && currentRequest.status ) {
		document.getElementById('test').innerText = currentRequest.responseText;
	}
}