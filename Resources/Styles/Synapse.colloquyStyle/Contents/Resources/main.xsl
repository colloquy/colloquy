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

		<span class="event">
			<span class="hidden">[<xsl:value-of select="$timestamp" />] </span>
			<xsl:apply-templates select="message/child::node()" mode="copy" />
			<xsl:text> (</xsl:text>
			<xsl:value-of select="$timestamp" />
			<xsl:text>) </xsl:text>
			<xsl:if test="reason!=''">
				<span class="reason">
					<xsl:text>Reason: </xsl:text>
					<xsl:apply-templates select="reason/child::node()" mode="copy"/>
				</span>
			</xsl:if>
			<br />
		</span>
	</xsl:template>

	<xsl:template match="message">
		<xsl:choose>
			<xsl:when test="count( ../message[@ignored != 'yes'] ) = 1 and @ignored != 'yes'">
				<xsl:apply-templates select=".." />
			</xsl:when>
			<xsl:otherwise>
				<xsl:if test="@ignored != 'yes' and ../@ignored != 'yes'">
					<xsl:variable name="messageClass">
						<xsl:choose>
							<xsl:when test="../sender/@self = 'yes'">
								<xsl:text>submessage self</xsl:text>
							</xsl:when>
							<xsl:when test="@highlight = 'yes'">
							  <xsl:text>submessage highlight</xsl:text>
							</xsl:when>
							<xsl:otherwise>
								<xsl:text>submessage</xsl:text>
							</xsl:otherwise>
						</xsl:choose>
					</xsl:variable>
	
					<xsl:variable name="timestamp">
						<xsl:call-template name="short-time">
							<xsl:with-param name="date" select="@received" />
						</xsl:call-template>
					</xsl:variable>

					<span class="{$messageClass}">
						<span class="hidden">[</span>
						<span class="time"><xsl:value-of select="$timestamp" /></span>
						<span class="hidden">] <xsl:if test="@action != 'yes'"><xsl:value-of select="../sender" />: </xsl:if></span>
						<xsl:if test="@action = 'yes'">
							<xsl:text>&#8226; </xsl:text>
							<a href="member:{../sender}" class="member action">
							<xsl:value-of select="../sender" />
							</a>
							<xsl:text> </xsl:text>
						</xsl:if>
						<xsl:apply-templates select="child::node()" mode="copy" />
						<br />
					</span>
					<xsl:if test="$subsequent = 'yes'">
						<xsl:processing-instruction name="message">type="subsequent"</xsl:processing-instruction>
						<span id="consecutiveInsert">&#8203;</span>
					</xsl:if>
				</xsl:if>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<xsl:template match="envelope">
		<xsl:if test="@ignored != 'yes' and count( message[@ignored != 'yes'] ) &gt;= 1">
			<xsl:variable name="messageClass">
				<xsl:choose>
					<xsl:when test="sender/@self = 'yes'">
						<xsl:text>message self</xsl:text>
					</xsl:when>
			        <xsl:when test="message[@ignored != 'yes'][1]/@highlight = 'yes'">
			          <xsl:text>message highlight</xsl:text>
			        </xsl:when>
					<xsl:otherwise>
						<xsl:text>message</xsl:text>
					</xsl:otherwise>
				</xsl:choose>
			</xsl:variable>

			<xsl:variable name="timestamp">
				<xsl:call-template name="short-time">
					<xsl:with-param name="date" select="message[@ignored != 'yes'][1]/@received" />
				</xsl:call-template>
			</xsl:variable>

			<span id="{@id}">
				<span class="{$messageClass}">
					<span class="hidden">[<xsl:value-of select="$timestamp" />] </span>
					<span class="header">
						<a href="member:{sender}" class="name"><xsl:value-of select="sender" /></a>
					</span>
					<span class="hidden">: </span>
					<span class="time" title="{$timestamp}">&#8203;</span>
					<xsl:if test="message[@ignored != 'yes'][1]/@action = 'yes'">
						<xsl:text>&#8226; </xsl:text>
						<a href="member:{sender}" class="member action">
						<xsl:value-of select="sender" />
						</a>
						<xsl:text> </xsl:text>
					</xsl:if>
					<xsl:apply-templates select="message[@ignored != 'yes'][1]/child::node()" mode="copy" />
					<br />
				</span>
				<xsl:apply-templates select="message[@ignored != 'yes'][position() &gt; 1]" />
				<xsl:if test="position() = last()">
					<span id="consecutiveInsert">&#8203;</span>
				</xsl:if>
				<span class="shadow">&#8203;</span>
			</span>
		</xsl:if>
	</xsl:template>

	<xsl:template match="span[@class='member']" mode="copy">
		<a href="member:{current()}" class="member"><xsl:value-of select="current()" /></a>
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
