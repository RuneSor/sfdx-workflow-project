#!/bin/sh
# Rune Sorensen - rune.sorensen@fluidogroup.com

# These support * notation
MetadataAll="AccountRelationshipShareRule,ActionLinkGroupTemplate,ApexClass,ApexComponent,
ApexPage,ApexTrigger,AppMenu,ApprovalProcess,ArticleType,AssignmentRules,Audience,AuthProvider,
AuraDefinitionBundle,AutoResponseRules,Bot,BrandingSet,CallCenter,Certificate,CleanDataService,
CMSConnectSource,Community,CommunityTemplateDefinition,CommunityThemeDefinition,CompactLayout,
ConnectedApp,ContentAsset,CorsWhitelistOrigin,CustomApplication,CustomApplicationComponent,
CustomFeedFilter,CustomHelpMenuSection,CustomMetadata,CustomLabels,CustomObjectTranslation,
CustomPageWebLink,CustomPermission,CustomSite,CustomTab,DataCategoryGroup,DelegateGroup,
DuplicateRule,EclairGeoData,EntitlementProcess,EntitlementTemplate,EventDelivery,EventSubscription,
ExternalServiceRegistration,ExternalDataSource,FeatureParameterBoolean,FeatureParameterDate,FeatureParameterInteger,
FieldSet,FlexiPage,Flow,FlowCategory,FlowDefinition,GlobalValueSet,GlobalValueSetTranslation,Group,HomePageComponent,
HomePageLayout,InstalledPackage,KeywordList,Layout,LightningBolt,LightningComponentBundle,LightningExperienceTheme,
LiveChatAgentConfig,LiveChatButton,LiveChatDeployment,LiveChatSensitiveDataRule,ManagedTopics,MatchingRules,MilestoneType,
MlDomain,ModerationRule,NamedCredential,Network,NetworkBranding,PathAssistant,PermissionSet,PlatformCachePartition,
Portal,PostTemplate,PresenceDeclineReason,PresenceUserConfig,Profile,ProfilePasswordPolicy,ProfileSessionSetting,
Queue,QueueRoutingConfig,QuickAction,RecommendationStrategy,RecordActionDeployment,ReportType,Role,SamlSsoConfig,
Scontrol,ServiceChannel,ServicePresenceStatus,SharingRules,SharingSet,SiteDotCom,Skill,StandardValueSetTranslation,
StaticResource,SynonymDictionary,Territory,Territory2,Territory2Model,Territory2Rule,Territory2Type,TopicsForObjects,
TransactionSecurityPolicy,Translations,WaveApplication,WaveDashboard,WaveDataflow,WaveDataset,WaveLens,WaveTemplateBundle,
WaveXmd,Workflow"
function timeStamp(){
    echo `date "+%Y/%m/%d %T"`
}
function generateNameXML(){
    local name=$1
    echo "<name>${name}</name>"
}
function generateMemberXML(){
    local member=$1
    if [ $member == "$$_" ]; then
        echo "<members>*</members>"
    else
        echo "<members>${member}</members>"
    fi   
}
function convertListMetadata(){
    local listMetadataJSON=$1
    if [ "${listMetadataJSON}" != "null" ]; then
        isArray=$(echo ${listMetadataJSON} | jq 'if type=="array" then 1 else 0 end')
        if [ "$isArray" == "1" ]; then
            listMetadataNames="$(echo ${listMetadataJSON} | jq -r '.[] | .fullName' | tr '\n' ':')"
        else 
            listMetadataNames="$(echo ${listMetadataJSON} | jq -r '.fullName' | tr '\n' ':')"
        fi
        echo ${listMetadataNames}
    fi
}
function listMetadataNames(){
    local apiVersion=$1
    local metadataTypeName=$2
    local metadataTypeInFolder=$3
    if [ "${metadataTypeInFolder}" == "true" ]; then
        if [ "${metadataTypeName}" == "Report" ]; then
            local metadataTypeNameFolder="ReportFolder"
        fi
        if [ "${metadataTypeName}" == "Dashboard" ]; then
            local metadataTypeNameFolder="DashboardFolder"
        fi
        if [ "${metadataTypeName}" == "Document" ]; then
            local metadataTypeNameFolder="DocumentFolder"
        fi
        if [ "${metadataTypeName}" == "EmailTemplate" ]; then
            local metadataTypeNameFolder="EmailFolder"
        fi
        local listMetadataFolderResult=$(echo $(sfdx force:mdapi:listmetadata -a ${apiVersion} -u ${aliasOrg} -m ${metadataTypeNameFolder} --json) | jq '.result')
        local listMetadataFolders=$(convertListMetadata "${listMetadataFolderResult}")
        local listMetadataAllFolderItems=""
        IFS=":" read -ra listMetadataFoldersArray <<< "${listMetadataFolders}"
        for folder in ${listMetadataFoldersArray[@]}; do 
            local listMetadataFolderItemResult=$(echo $(sfdx force:mdapi:listmetadata -a ${apiVersion} -u ${aliasOrg} -m ${metadataTypeName} --folder ${folder} --json) | jq '.result')
            local listMetadataFolderItems="$(convertListMetadata "${listMetadataFolderItemResult}")"
            if [ "${listMetadataFolderItems}" != "" ]; then
                listMetadataAllFolderItems="${listMetadataAllFolderItems}${listMetadataFolderItems}"
            fi
        done
        local listMetadata="${listMetadataFolders}${listMetadataAllFolderItems}"
        echo "${listMetadata}"
    else
        isMetadataAll=`echo $MetadataAll | grep -wc ${metadataTypeName}`
        if [ $isMetadataAll -eq 1 ]; then
            echo "$$_"
        else
            local listMetadataResult=$(echo $(sfdx force:mdapi:listmetadata -a ${apiVersion} -u ${aliasOrg} -m ${metadataTypeName} --json) | jq '.result')
            echo "$(convertListMetadata "${listMetadataResult}")"
        fi
    fi
}
function generateTypeXML(){
    local apiVersion=$1
    local metadataTypeName=$2
    local metadataTypeInFolder=$3
    local listMetadataNames="$(listMetadataNames ${apiVersion} ${metadataTypeName} ${metadataTypeInFolder})"
    if [ "${listMetadataNames}" != "" ]; then
        echo "  <types>"
        IFS=":"
        for metadataName in ${listMetadataNames}; do 
            echo "      $(generateMemberXML ${metadataName})"
        done
        echo "      $(generateNameXML ${metadataTypeName})"
        echo "  </types>"
    fi
}
function filterRestrictedMetadata(){
    local metadataType=$1
    if [ -f ${restrictfilename} ]; then
        echo $(grep -w ${metadataType} ${restrictfilename} | wc -l)
    else
        echo 0
    fi
}
function generatePackageXML(){
    local apiVersion=$1
    local describeMetadata=$(sfdx force:mdapi:describemetadata -a ${apiVersion} -u ${aliasOrg} --json | jq -r '.result.metadataObjects | .[] | "\(.xmlName) \(.inFolder)"' | tr '\r' ' ')
    echo '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    echo '<Package xmlns="http://soap.sforce.com/2006/04/metadata">'
    IFS=' '
    while read -r metadataType inFolder; do
        if [ "$(filterRestrictedMetadata ${metadataType} ${restrictfilename})" = 0 ]; then
            echo "$(timeStamp) ${metadataType}" >&2
          
            local typeXML="$(generateTypeXML ${apiVersion} ${metadataType} ${inFolder})"
            
            if [ "${typeXML}" != "" ]; then
                echo "${typeXML}"
            fi
        fi
    done <<< "$describeMetadata"
    echo "  <version>${apiVersion}</version>"
    echo '</Package>'
    echo "$(timeStamp) End Generate Package XML " >&2
}
main() {
    local apiVersion=${1:-'46.0'}
    local outputFile=${2:-'package.xml'}
    local aliasOrg=${3:-'devHubAlias'}
    local restrictfilename=${4:-'restrictedmetadata.txt'} # list of metadata we NOT want listed in package.xml
    generatePackageXML ${apiVersion} > ${outputFile}
}
main "$@"