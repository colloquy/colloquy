<xsl:transform xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
	<xsl:output omit-xml-declaration="yes" indent="no" />
	<xsl:param name="subsequent" />
	<xsl:param name="timeFormat" />

	<xsl:template match="/">
		<xsl:choose>
			<xsl:when test="$subsequent != 'yes'">
				<xsl:apply-templates />
			</xsl:when>
			<xsl:otherwise>
				<xsl:apply-templates select="/envelope/message[last()]" mode="subsequent" />
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<xsl:template match="message" mode="subsequent">
		<div class="sep">&#8203;</div>
		<div class="time">
			<xsl:call-template name="short-time">
				<xsl:with-param name="date" select="@received" />
			</xsl:call-template>
		</div>
		<div class="message">
			<xsl:if test="@action = 'yes'">
				<xsl:text>&#8226; </xsl:text>
				<xsl:value-of select="../sender" />
				<xsl:text> </xsl:text>
			</xsl:if>
			<xsl:apply-templates select="child::node()" mode="copy" />
		</div>
		<xsl:if test="$subsequent = 'yes'">
			<div id="consecutiveInsert">&#8203;</div>
		</xsl:if>
	</xsl:template>

	<xsl:template match="envelope">
		<xsl:variable name="senderClasses">
			<xsl:choose>
				<xsl:when test="message[1]/@highlight = 'yes'">
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

		<div id="{@id}" class="{$senderClasses}">
			<div class="header_top">&#8203;</div>
			<div class="header">
				<div>
					<div>
					<div class="sender"><xsl:value-of select="sender" /></div>
					</div>
				</div>
				<div class="left">&#8203;</div>
				<div class="right">&#8203;</div>
			</div>
			<div class="messages">
				<div>
					<div>
						<div class="time">
						<xsl:call-template name="short-time">
							<xsl:with-param name="date" select="message[1]/@received" />
						</xsl:call-template>
						</div>
						<div class="message">
						<xsl:if test="message[1]/@action = 'yes'">
							<xsl:text>&#8226; </xsl:text>
							<xsl:value-of select="sender" />
							<xsl:text> </xsl:text>
						</xsl:if>
							<xsl:apply-templates select="message[1]/child::node()" mode="copy" />
						</div>
						<xsl:apply-templates select="message[position() &gt; 1]" mode="subsequent" />
						<xsl:if test="position() = last()">
							<div id="consecutiveInsert">&#8203;</div>
						</xsl:if>
					</div>
				</div>
			</div>
			<div class="messages_bottom">
				<div class="left">&#8203;</div>
				<div class="right">&#8203;</div>
			</div>
		</div>
	</xsl:template>

	<xsl:template match="event">
		<div class="event">
			<div class="time">
				<xsl:call-template name="short-time">
					<xsl:with-param name="date" select="@occurred" />
				</xsl:call-template>
			</div>
			<div class="message">
			<xsl:copy-of select="message/child::node()" />
			<xsl:if test="reason!=''">
				<span class="reason">
					<xsl:text> (</xsl:text>
					<xsl:apply-templates select="reason/child::node()" mode="copy" />
					<xsl:text>)</xsl:text>
				</span>
			</xsl:if>
			</div>
		</div>
	</xsl:template>

	<xsl:template match="a" mode="copy">
		<xsl:variable name="extension" select="substring(@href,string-length(@href) - 3, 4)" />
		<xsl:variable name="extensionLong" select="substring(@href,string-length(@href) - 4, 5)" />

		<xsl:choose>
			<xsl:when test="$extension = '.jpg' or $extension = '.JPG' or $extensionLong = '.jpeg' or $extensionLong = '.JPEG'">
				<a href="{@href}" title="{@href}"><img src="{@href}" alt="Loading Image..." onload="resizeIfNeeded( this )" /></a>
			</xsl:when>
			<xsl:when test="$extension = '.gif' or $extension = '.GIF'">
				<a href="{@href}" title="{@href}"><img src="{@href}" alt="Loading Image..." onload="resizeIfNeeded( this )" /></a>
			</xsl:when>
			<xsl:when test="$extension = '.png' or $extension = '.PNG'">
				<a href="{@href}" title="{@href}"><img src="{@href}" alt="Loading Image..." onload="resizeIfNeeded( this )" /></a>
			</xsl:when>
			<xsl:when test="$extension = '.tif' or $extension = '.TIF' or $extensionLong = '.tiff' or $extensionLong = '.TIFF'">
				<a href="{@href}" title="{@href}"><img src="{@href}" alt="Loading Image..." onload="resizeIfNeeded( this )" /></a>
			</xsl:when>
			<xsl:when test="$extension = '.pdf' or $extension = '.PDF'">
				<a href="{@href}" title="{@href}"><img src="{@href}" alt="Loading Image..." onload="resizeIfNeeded( this )" /></a>
			</xsl:when>
			<xsl:when test="$extension = '.bmp' or $extension = '.BMP'">
				<a href="{@href}" title="{@href}"><img src="{@href}" alt="Loading Image..." onload="resizeIfNeeded( this )" /></a>
			</xsl:when>
			<xsl:otherwise>
				<xsl:copy-of select="current()"/>
			</xsl:otherwise>
		</xsl:choose>
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
