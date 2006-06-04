<xsl:transform xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
	<xsl:output omit-xml-declaration="yes" indent="no" />
	<xsl:param name="consecutiveMessage" />
	<xsl:param name="timeFormat" />

	<xsl:template match="/">
		<xsl:choose>
			<xsl:when test="$consecutiveMessage = 'yes'">
				<xsl:apply-templates select="/envelope/message[last()]" />
			</xsl:when>
			<xsl:otherwise>
				<xsl:apply-templates />
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
			<xsl:if test="string-length( reason )">
				<span class="reason">
					<xsl:text> (</xsl:text>
					<xsl:apply-templates select="reason/child::node()" mode="copy"/>
					<xsl:text>)</xsl:text>
				</span>
			</xsl:if>
		</div>
	</xsl:template>

	<xsl:template match="sender">
	</xsl:template>

	<xsl:template match="message">
		<xsl:if test="not( ../@ignored = 'yes' ) and not( @ignored = 'yes' )">
			<xsl:variable name="envelopeClass">
				<xsl:choose>
					<xsl:when test="@highlight = 'yes'">
						<xsl:text>envelopeHighlight</xsl:text>
					</xsl:when>
					<xsl:otherwise>
						<xsl:text>envelope</xsl:text>
					</xsl:otherwise>
				</xsl:choose>
			</xsl:variable>

			<xsl:variable name="senderClass">
				<xsl:choose>
					<xsl:when test="../sender/@self = 'yes'">
						<xsl:text>senderSelf</xsl:text>
					</xsl:when>
					<xsl:otherwise>
						<xsl:text>sender</xsl:text>
					</xsl:otherwise>
				</xsl:choose>
			</xsl:variable>

			<xsl:variable name="timestamp">
				<xsl:call-template name="short-time">
					<xsl:with-param name="date" select="@received" />
				</xsl:call-template>
			</xsl:variable>

			<div id="{@id}" class="{$envelopeClass}">
				<span class="hidden">[<xsl:value-of select="$timestamp" />] </span>
				<xsl:choose>
					<xsl:when test="@action = 'yes'">
						<span class="{$senderClass}"><xsl:value-of select="../sender" /></span>
						<xsl:text> </xsl:text>
						<xsl:value-of select="normalize-space(node())" />
					</xsl:when>
					<xsl:when test="contains(node(), ',')">
						<span class="hidden">&quot;</span>
						<q lang="en">
							<span class="message"><xsl:value-of select="normalize-space(substring-before( current(), ',' ))" /></span>
							<xsl:text>,</xsl:text>
						</q>
						<span class="hidden">&quot;</span>
						<xsl:text> </xsl:text>
						<span class="{$senderClass}"><xsl:value-of select="../sender" /></span>
						<xsl:choose>
							<xsl:when test="substring( current(), string-length( current() ), 1 ) = '?'">
								<xsl:text> asks </xsl:text>
							</xsl:when>
							<xsl:when test="substring( current(), string-length( current() ), 1 ) = '!'">
								<xsl:text> exclaims </xsl:text>
							</xsl:when>
							<xsl:otherwise>
								<xsl:text> says </xsl:text>
							</xsl:otherwise>
						</xsl:choose>
						<span class="hidden">&quot;</span>
						<q lang="en">
							<span class="message"><xsl:value-of select="normalize-space(substring-after( current(), ',' ))" /></span>
						</q>
						<span class="hidden">&quot;</span>
					</xsl:when>
					<xsl:otherwise>
						<span class="hidden">&quot;</span>
						<q lang="en">
							<span class="message"><xsl:value-of select="normalize-space( current() )" /></span>
							<xsl:text>,</xsl:text>
						</q>
						<span class="hidden">&quot;</span>
						<xsl:choose>
							<xsl:when test="substring( current(), string-length( current() ), 1 ) = '?'">
								<xsl:text> asked </xsl:text>
							</xsl:when>
							<xsl:when test="substring( current(), string-length( current() ), 1 ) = '!'">
								<xsl:text> exclaimed </xsl:text>
							</xsl:when>
							<xsl:otherwise>
								<xsl:text> said </xsl:text>
							</xsl:otherwise>
						</xsl:choose>
						<span class="{$senderClass}"><xsl:value-of select="../sender" /></span>
						<xsl:text>.</xsl:text>
					</xsl:otherwise>
				</xsl:choose>
			</div>
		</xsl:if>
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
