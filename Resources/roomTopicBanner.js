var topicSize = 0;
var topicToggled = false;

function toggleTopic( e ) {
	if( e && e.altKey ) {
		topicSize++;
		if( topicSize > 3 ) topicSize = 0;
		topicAreaSize = ( ! topicSize ? 17 : ( topicSize == 1 ? 32 : ( topicSize == 2 ? 47 : 62 ) ) );
		if( topicSize == 3 ) document.getElementById( 'toggleButton' ).className = "up";
		else document.getElementById( 'toggleButton' ).className = "";
	} else {
		if( ! topicToggled && topicSize < 3 ) {
			topicAreaSize = document.getElementById( 'topicMessage' ).clientHeight + 2;
			if( topicAreaSize > 62 ) topicAreaSize = 62;
			else if( topicAreaSize < 17 ) topicAreaSize = 17;
			document.getElementById( 'toggleButton' ).className = "up";
			topicToggled = true;
		} else {
			if( topicSize == 3 ) topicSize = 0;
			topicAreaSize = ( ! topicSize ? 17 : ( topicSize == 1 ? 32 : ( topicSize == 2 ? 47 : 62 ) ) );
			document.getElementById( 'toggleButton' ).className = "";
			topicToggled = false;
		}
	}

	document.getElementById( 'topicArea' ).style.setProperty( 'height', topicAreaSize + 'px', null );
}

function changeTopic( topic, author, empty ) {
	topicMessage = document.getElementById( 'topicMessage' );
	topicMessage.innerHTML = topic;
	topicMessage.title = topicMessage.innerText + ' set by ' + author;
	refreshTopicSize();
}

function refreshTopicSize() {
	topicMessage = document.getElementById( 'topicMessage' );
	if( topicMessage.clientHeight > 17 )
		document.getElementById( 'toggleButton' ).style.setProperty( 'display', 'block', null );
	else document.getElementById( 'toggleButton' ).style.setProperty( 'display', 'none', null );
	if( topicToggled ) {
		topicAreaSize = topicMessage.clientHeight + 2;
		if( topicAreaSize > 62 ) topicAreaSize = 62;
		else if( topicAreaSize < 17 ) topicAreaSize = 17;
		document.getElementById( 'topicArea' ).style.setProperty( 'height', topicAreaSize + 'px', null );
	}
}

window.addEventListener( 'resize', refreshTopicSize );
