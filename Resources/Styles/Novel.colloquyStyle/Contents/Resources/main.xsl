<xsl:transform xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
	<xsl:output omit-xml-declaration="yes" indent="no" />
	<xsl:param name="subsequent" />

	<xsl:template match="/">
		<xsl:choose>
			<xsl:when test="$subsequent != 'yes'">
				<xsl:apply-templates />
			</xsl:when>
			<xsl:otherwise>
				<xsl:apply-templates select="/envelope/message[last()]" />
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<xsl:template match="event">
		<xsl:variable name="timestamp">
			<xsl:call-template name="short-time">
				<xsl:with-param name="date" select="@occurred" />
			</xsl:call-template>
		</xsl:variable>

		<div class="event">
			<span class="hidden">[<xsl:value-of select="$timestamp" />] </span>
			<xsl:copy-of select="message/child::node()" />
			<xsl:if test="reason!=''">
				<span class="reason">
					<xsl:text> (</xsl:text>
					<xsl:apply-templates select="reason/child::node()" mode="copy"/>
					<xsl:text>)</xsl:text>
				</span>
			</xsl:if>
		</div>
	</xsl:template>

	<xsl:template match="message">
		<span class="submessage">
		<xsl:if test="@action = 'yes'">
			<xsl:value-of select="../sender" />
			<xsl:text> </xsl:text>
		</xsl:if>
		<xsl:value-of select="normalize-space(.)" />
		</span>
		<xsl:if test="$subsequent = 'yes'">
			<span id="consecutiveInsert" />
		</xsl:if>
	</xsl:template>

	<xsl:template match="envelope">
		<xsl:variable name="envelopeClass">
			<xsl:choose>
				<xsl:when test="message/@highlight = 'yes'">
					<xsl:text>envelopeHighlight</xsl:text>
				</xsl:when>
				<xsl:otherwise>
					<xsl:text>envelope</xsl:text>
				</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>

		<xsl:variable name="senderClass">
			<xsl:choose>
				<xsl:when test="sender/@self = 'yes'">
					<xsl:text>senderSelf</xsl:text>
				</xsl:when>
				<xsl:otherwise>
					<xsl:text>sender</xsl:text>
				</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>

		<xsl:variable name="timestamp">
			<xsl:call-template name="short-time">
				<xsl:with-param name="date" select="message[1]/@received" />
			</xsl:call-template>
		</xsl:variable>

		<div id="{@id}" class="{$envelopeClass}">
			<span class="hidden">[<xsl:value-of select="$timestamp" />] </span>
			<xsl:choose>
				<xsl:when test="message[1]/@action = 'yes'">
					<span class="{$senderClass}"><xsl:value-of select="sender" /></span>
					<xsl:text> </xsl:text>
					<xsl:value-of select="normalize-space(message[1])" />
					<xsl:text> </xsl:text>
					<q lang="en">
						<xsl:apply-templates select="message[position() &gt; 1]" />
						<xsl:if test="position() = last()">
							<span id="consecutiveInsert" />
						</xsl:if>
					</q>
				</xsl:when>
				<xsl:when test="contains(message[1], ',')">
					<span class="hidden">&quot;</span>
					<q lang="en">
						<span class="message"><xsl:value-of select="normalize-space(substring-before( message[1], ',' ))" /></span>
						<xsl:text>,</xsl:text>
					</q>
					<span class="hidden">&quot;</span>
					<xsl:text> </xsl:text>
					<span class="{$senderClass}"><xsl:value-of select="sender" /></span>
					<xsl:choose>
						<xsl:when test="substring( message[1], string-length( message[1] ), 1 ) = '?'">
							<xsl:text> asks </xsl:text>
						</xsl:when>
						<xsl:when test="substring( message[1], string-length( message[1] ), 1 ) = '!'">
							<xsl:text> exclaims </xsl:text>
						</xsl:when>
						<xsl:otherwise>
							<xsl:text> says </xsl:text>
						</xsl:otherwise>
					</xsl:choose>
					<span class="hidden">&quot;</span>
					<q lang="en">
						<span class="message"><xsl:value-of select="normalize-space(substring-after( message[1], ',' ))" /></span>
						<xsl:apply-templates select="message[position() &gt; 1]" />
						<xsl:if test="position() = last()">
							<span id="consecutiveInsert" />
						</xsl:if>
					</q>
					<span class="hidden">&quot;</span>
				</xsl:when>
				<xsl:otherwise>
					<span class="hidden">&quot;</span>
					<q lang="en">
						<span class="message"><xsl:value-of select="normalize-space(message[1])" /></span>
						<xsl:text>,</xsl:text>
					</q>
					<span class="hidden">&quot;</span>
					<xsl:choose>
						<xsl:when test="substring( message[1], string-length( message[1] ), 1 ) = '?'">
							<xsl:text> asked </xsl:text>
						</xsl:when>
						<xsl:when test="substring( message[1], string-length( message[1] ), 1 ) = '!'">
							<xsl:text> exclaimed </xsl:text>
						</xsl:when>
						<xsl:otherwise>
							<xsl:text> said </xsl:text>
						</xsl:otherwise>
					</xsl:choose>
					<span class="{$senderClass}"><xsl:value-of select="sender" /></span>
					<xsl:text>. </xsl:text>
					<span class="hidden">&quot;</span>
					<q lang="en">
						<xsl:apply-templates select="message[position() &gt; 1]" />
						<xsl:if test="position() = last()">
							<span id="consecutiveInsert" />
						</xsl:if>
					</q>
					<span class="hidden">&quot;</span>
				</xsl:otherwise>
			</xsl:choose>
		</div>
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
			<xsl:text>PM</xsl:text>
		      </xsl:when>
		      <xsl:otherwise>
			<xsl:text>AM</xsl:text>
		      </xsl:otherwise>
		    </xsl:choose>
		  </xsl:otherwise>
		</xsl:choose>
	</xsl:template>
</xsl:transform>
