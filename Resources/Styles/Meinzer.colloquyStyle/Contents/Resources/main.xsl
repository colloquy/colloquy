<xsl:transform xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
	<xsl:output omit-xml-declaration="yes" indent="yes" />
	<xsl:template match="event">
	<div align="center">
		<span class="event">
		<xsl:copy-of select="message/child::node()" />
		<xsl:text> (</xsl:text>
		<xsl:call-template name="short-time">
			<xsl:with-param name="date" select="@occurred" />
		</xsl:call-template>
		<xsl:text>)</xsl:text>
		</span>
	</div>
	<br />
	</xsl:template>
	<xsl:template match="envelope">
		<xsl:variable name="messageClass">
			<xsl:choose>
				<xsl:when test="sender/@self = 'yes'">
					<xsl:text>msg1</xsl:text>
				</xsl:when>
		        <xsl:when test="message/@highlight = 'yes'">
		          <xsl:text>msg3</xsl:text>
		        </xsl:when>
				<xsl:otherwise>
					<xsl:text>msg2</xsl:text>
				</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>
		<div id="{@id}" class="{$messageClass}">
			<div class="name_time">
				<span class="name"><xsl:value-of select="sender" /></span>
				<span class="time">
					<xsl:call-template name="short-time">
						<xsl:with-param name="date" select="@received" />
					</xsl:call-template>
				</span>
			</div>
      		<xsl:if test="message/@action = 'yes'">
				<xsl:text>• </xsl:text>
				<xsl:value-of select="sender" />
				<xsl:text> </xsl:text>
			</xsl:if>
			<xsl:copy-of select="message/child::node()" />
		</div>
		<div class="shadow">&#8203;</div>
	</xsl:template>
	<xsl:template name="short-time">
		<xsl:param name="date" /> <!-- YYYY-MM-DD HH:MM:SS +/-HHMM -->
		<xsl:choose>
			<xsl:when test="number(substring($date, 12, 2)) &gt; 12">
				<xsl:value-of select="number(substring($date, 12, 2)) - 12" />
			</xsl:when>
			<xsl:when test="number(substring($date, 12, 2)) = 0">
				<xsl:text>12</xsl:text>
			</xsl:when>
			<xsl:otherwise>
				<xsl:value-of select="number(substring($date, 12, 2))" />
			</xsl:otherwise>
		</xsl:choose>
		<xsl:text>:</xsl:text>
		<xsl:value-of select="substring($date, 15, 2)" />
		<xsl:choose>
			<xsl:when test="number(substring($date, 12, 2)) &gt;= 12">
				<xsl:text>pm</xsl:text>
			</xsl:when>
			<xsl:otherwise>
				<xsl:text>am</xsl:text>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>
</xsl:transform>
