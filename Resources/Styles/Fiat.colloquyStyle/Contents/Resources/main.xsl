<xsl:transform xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
	<xsl:output omit-xml-declaration="yes" indent="no" />
	<xsl:param name="consecutiveMessage" />
	<xsl:param name="bulkTransform" />
	<xsl:param name="timeFormat" />

	<xsl:template match="/">
		<xsl:choose>
			<xsl:when test="$consecutiveMessage = 'yes'">
				<xsl:apply-templates select="/envelope/message[last()]" mode="consecutive">
					<xsl:with-param name="fromEnvelope" select="'no'" />
				</xsl:apply-templates>
			</xsl:when>
			<xsl:otherwise>
				<xsl:apply-templates />
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<xsl:template match="message" mode="consecutive">
		<xsl:param name="fromEnvelope" select="'no'" />

		<xsl:choose>
			<xsl:when test="not( $consecutiveMessage = 'yes' ) and $fromEnvelope = 'no' and count( ../message[not( @ignored = 'yes' )] ) = 1 and not( @ignored = 'yes' )">
				<xsl:apply-templates select=".." />
			</xsl:when>
			<xsl:otherwise>
				<xsl:if test="not( @ignored = 'yes' ) and not( ../@ignored = 'yes' )">
					<xsl:variable name="timestamp">
						<xsl:call-template name="short-time">
							<xsl:with-param name="date" select="@received" />
						</xsl:call-template>
					</xsl:variable>

					<xsl:variable name="memberLink">
						<xsl:choose>
							<xsl:when test="../sender/@identifier">
								<xsl:text>member:identifier:</xsl:text><xsl:value-of select="../sender/@identifier" />
							</xsl:when>
							<xsl:when test="../sender/@nickname">
								<xsl:text>member:</xsl:text><xsl:value-of select="../sender/@nickname" />
							</xsl:when>
							<xsl:otherwise>
								<xsl:text>member:</xsl:text><xsl:value-of select="../sender" />
							</xsl:otherwise>
						</xsl:choose>
					</xsl:variable>

					<span class="sep"><xsl:text> </xsl:text></span>
					<span class="hidden">[</span>
					<span class="time inline"><xsl:value-of select="$timestamp" /></span>
					<span class="hidden">] <xsl:if test="not( @action = 'yes' )"><xsl:value-of select="../sender" />: </xsl:if></span>
					<span id="{@id}" class="message">
						<xsl:if test="@action = 'yes'">
							<xsl:text>&#8226; </xsl:text>
							<a href="{$memberLink}" class="member action">
							<xsl:value-of select="../sender" />
							</a>
							<xsl:text> </xsl:text>
						</xsl:if>
						<xsl:apply-templates select="child::node()" mode="copy" />
						<br />
					</span>
					<xsl:if test="not( $bulkTransform = 'yes' )">
						<xsl:if test="$fromEnvelope = 'no'">
							<xsl:processing-instruction name="message">type="consecutive"</xsl:processing-instruction>
						</xsl:if>
						<span id="consecutiveInsert"><xsl:text> </xsl:text></span>
					</xsl:if>
				</xsl:if>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<xsl:template match="envelope">
		<xsl:if test="not( @ignored = 'yes' ) and count( message[not( @ignored = 'yes' )] ) &gt;= 1">
			<xsl:variable name="senderClasses">
				<xsl:choose>
					<xsl:when test="message[not( @ignored = 'yes' )][1]/@highlight = 'yes'">
						<xsl:text>incoming highlight</xsl:text>
					</xsl:when>
					<xsl:when test="sender/@self = 'yes'">
						<xsl:text>outgoing</xsl:text>
					</xsl:when>
					<xsl:otherwise>
						<xsl:text>incoming</xsl:text>
					</xsl:otherwise>
				</xsl:choose>
			</xsl:variable>

			<xsl:variable name="timestamp">
				<xsl:call-template name="short-time">
					<xsl:with-param name="date" select="message[not( @ignored = 'yes' )][1]/@received" />
				</xsl:call-template>
			</xsl:variable>

			<xsl:variable name="memberLink">
				<xsl:choose>
					<xsl:when test="sender/@identifier">
						<xsl:text>member:identifier:</xsl:text><xsl:value-of select="sender/@identifier" />
					</xsl:when>
			        <xsl:when test="sender/@nickname">
						<xsl:text>member:</xsl:text><xsl:value-of select="sender/@nickname" />
			        </xsl:when>
					<xsl:otherwise>
						<xsl:text>member:</xsl:text><xsl:value-of select="sender" />
					</xsl:otherwise>
				</xsl:choose>
			</xsl:variable>

			<span class="{$senderClasses}">
				<span class="hidden">[<xsl:value-of select="$timestamp" />] </span>
				<span class="header_top"><xsl:text> </xsl:text></span>
				<span class="header">
					<span>
						<span>
						<span class="sender">
						<a href="{$memberLink}" class="member">
						<xsl:value-of select="sender" />
						</a>
						</span>
						</span>
					</span>
					<span class="left"><xsl:text> </xsl:text></span>
					<span class="right"><xsl:text> </xsl:text></span>
				</span>
				<span class="hidden">: </span>
				<span class="messages">
					<span>
						<span>
							<span class="time" title="{$timestamp}"><xsl:text> </xsl:text></span>
							<span id="{message[not( @ignored = 'yes' )][1]/@id}" class="message">
								<xsl:if test="message[not( @ignored = 'yes' )][1]/@action = 'yes'">
									<xsl:text>&#8226; </xsl:text>
									<a href="{$memberLink}" class="member action">
									<xsl:value-of select="sender" />
									</a>
									<xsl:text> </xsl:text>
								</xsl:if>
								<xsl:apply-templates select="message[not( @ignored = 'yes' )][1]/child::node()" mode="copy" />
								<br />
							</span>
							<xsl:apply-templates select="message[not( @ignored = 'yes' )][position() &gt; 1]" mode="consecutive">
								<xsl:with-param name="fromEnvelope" select="'yes'" />
							</xsl:apply-templates>
							<xsl:if test="position() = last()">
								<span id="consecutiveInsert"><xsl:text> </xsl:text></span>
							</xsl:if>
						</span>
					</span>
				</span>
				<span class="messages_bottom">
					<span class="left"><xsl:text> </xsl:text></span>
					<span class="right"><xsl:text> </xsl:text></span>
				</span>
			</span>
		</xsl:if>
	</xsl:template>

	<xsl:template match="event">
		<xsl:variable name="timestamp">
			<xsl:call-template name="short-time">
				<xsl:with-param name="date" select="@occurred" />
			</xsl:call-template>
		</xsl:variable>

		<span class="event">
		<span class="hidden">[</span>
		<span class="time"><xsl:value-of select="$timestamp" /></span>
		<span class="hidden">] </span>
			<span class="message">
			<xsl:apply-templates select="message/child::node()" mode="event" />
			<xsl:if test="string-length( reason )">
				<span class="reason">
					<xsl:text> (</xsl:text>
					<xsl:apply-templates select="reason/child::node()" mode="copy" />
					<xsl:text>)</xsl:text>
				</span>
			</xsl:if>
			<br />
			</span>
		</span>
	</xsl:template>

	<xsl:template match="a" mode="copy">
		<xsl:variable name="extension" select="substring(@href,string-length(@href) - 3, 4)" />
		<xsl:variable name="extensionLong" select="substring(@href,string-length(@href) - 4, 5)" />

		<xsl:choose>
			<xsl:when test="$extension = '.jpg' or $extension = '.JPG' or $extensionLong = '.jpeg' or $extensionLong = '.JPEG'">
				<a href="{@href}" title="{@href}"><img src="{@href}" alt="Loading Image..." onload="scrollToBottom()" /></a>
			</xsl:when>
			<xsl:when test="$extension = '.gif' or $extension = '.GIF'">
				<a href="{@href}" title="{@href}"><img src="{@href}" alt="Loading Image..." onload="scrollToBottom()" /></a>
			</xsl:when>
			<xsl:when test="$extension = '.png' or $extension = '.PNG'">
				<a href="{@href}" title="{@href}"><img src="{@href}" alt="Loading Image..." onload="scrollToBottom()" /></a>
			</xsl:when>
			<xsl:when test="$extension = '.tif' or $extension = '.TIF' or $extensionLong = '.tiff' or $extensionLong = '.TIFF'">
				<a href="{@href}" title="{@href}"><img src="{@href}" alt="Loading Image..." onload="scrollToBottom()" /></a>
			</xsl:when>
			<xsl:when test="$extension = '.pdf' or $extension = '.PDF'">
				<a href="{@href}" title="{@href}"><img src="{@href}" alt="Loading Image..." onload="scrollToBottom()" /></a>
			</xsl:when>
			<xsl:when test="$extension = '.bmp' or $extension = '.BMP'">
				<a href="{@href}" title="{@href}"><img src="{@href}" alt="Loading Image..." onload="scrollToBottom()" /></a>
			</xsl:when>
			<xsl:otherwise>
				<xsl:copy-of select="current()"/>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<xsl:template match="span[contains(@class,'member')]" mode="event">
		<xsl:variable name="nickname" select="current()" />
		<xsl:choose>
			<xsl:when test="../../node()[node() = $nickname]/@hostmask">
				<xsl:variable name="hostmask" select="../../node()[node() = $nickname]/@hostmask" />
				<a href="member:{$nickname}" title="{$hostmask}"><xsl:copy-of select="@*" /><xsl:value-of select="$nickname" /></a>
				<xsl:if test="../../@name = 'memberJoined' or ../../@name = 'memberParted'">
					<span class="hostmask">
						<xsl:text> (</xsl:text>
						<xsl:value-of select="$hostmask" />
						<xsl:text>) </xsl:text>
					</span>
				</xsl:if>
			</xsl:when>
			<xsl:otherwise>
				<a href="member:{$nickname}"><xsl:copy-of select="@*" /><xsl:apply-templates select="current()/child::node()" mode="copy" /></a>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<xsl:template match="span[contains(@class,'member')]" mode="copy">
		<a href="member:{current()}"><xsl:copy-of select="@*" /><xsl:apply-templates select="current()/child::node()" mode="copy" /></a>
	</xsl:template>

	<xsl:template match="@*|*" mode="event">
		<xsl:copy><xsl:apply-templates select="@*|node()" mode="event" /></xsl:copy>
	</xsl:template>

	<xsl:template match="@*|*" mode="copy">
		<xsl:copy><xsl:apply-templates select="@*|node()" mode="copy" /></xsl:copy>
	</xsl:template>

	<xsl:template name="short-time">
		<xsl:param name="date" /> <!-- YYYY-MM-DD HH:MM:SS +/-HHMM -->
		<xsl:variable name='hour' select='substring($date, 12, 2)' />
		<xsl:variable name='minute' select='substring($date, 15, 2)' />
		<xsl:choose>
		  <xsl:when test="contains($timeFormat,'H')">
		    <!-- 24hr format -->
		    <xsl:value-of select="concat($hour,':',$minute)" />
		  </xsl:when>
		  <xsl:otherwise>
		    <!-- am/pm format -->
		    <xsl:choose>
		      <xsl:when test="number($hour) &gt; 12">
			<xsl:value-of select="number($hour) - 12" />
		      </xsl:when>
		      <xsl:when test="number($hour) = 0">
			<xsl:text>12</xsl:text>
		      </xsl:when>
		      <xsl:otherwise>
			<xsl:value-of select="$hour" />
		      </xsl:otherwise>
		    </xsl:choose>
		    <xsl:text>:</xsl:text>
		    <xsl:value-of select="$minute" />
		    <xsl:choose>
		      <xsl:when test="number($hour) &gt;= 12">
			<xsl:text>p</xsl:text>
		      </xsl:when>
		      <xsl:otherwise>
			<xsl:text>a</xsl:text>
		      </xsl:otherwise>
		    </xsl:choose>
		  </xsl:otherwise>
		</xsl:choose>
	</xsl:template>
</xsl:transform>
