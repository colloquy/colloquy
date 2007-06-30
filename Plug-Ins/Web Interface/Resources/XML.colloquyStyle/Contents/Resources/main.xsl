<?xml version='1.0' encoding='utf-8'?>
<xsl:stylesheet version='1.0' xmlns:xsl='http://www.w3.org/1999/XSL/Transform'>
	<xsl:output omit-xml-declaration="yes" indent="no" />
	<xsl:param name="consecutiveMessage" />
	<xsl:param name="bulkTransform" />
	<xsl:param name="timeFormat" />

	<xsl:template match="log">
		<xsl:apply-templates select="*" />
	</xsl:template>

	<xsl:template match="envelope">
		<xsl:apply-templates select="message[last()]" />
	</xsl:template>

	<xsl:template match="envelope/message">
	</xsl:template>

	<xsl:template match="envelope/message[last()]">
		<envelope>
		<xsl:apply-templates select="../sender" />
		<xsl:copy><xsl:apply-templates select="@*|node()" /></xsl:copy>
		</envelope>
	</xsl:template>

	<xsl:template match="@*|*">
		<xsl:copy><xsl:apply-templates select="@*|node()" /></xsl:copy>
	</xsl:template>
</xsl:stylesheet>
