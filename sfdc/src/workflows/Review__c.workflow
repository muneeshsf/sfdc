<?xml version="1.0" encoding="UTF-8"?>
<Workflow xmlns="http://soap.sforce.com/2006/04/metadata">
    <fieldUpdates>
        <fullName>Check_Review_Completed</fullName>
        <field>Review_Completed__c</field>
        <literalValue>1</literalValue>
        <name>Check Review Completed</name>
        <notifyAssignee>false</notifyAssignee>
        <operation>Literal</operation>
        <protected>false</protected>
    </fieldUpdates>
    <fieldUpdates>
        <fullName>Uncheck_Review_Completed</fullName>
        <field>Review_Completed__c</field>
        <literalValue>0</literalValue>
        <name>Uncheck Review Completed</name>
        <notifyAssignee>false</notifyAssignee>
        <operation>Literal</operation>
        <protected>false</protected>
    </fieldUpdates>
    <rules>
        <fullName>Review is Complete</fullName>
        <actions>
            <name>Check_Review_Completed</name>
            <type>FieldUpdate</type>
        </actions>
        <active>true</active>
        <formula>AND(NOT(ISNULL(Cultural_Fit__c)), NOT(ISNULL(Experience__c)), NOT(ISNULL(Leadership_Skills__c)))</formula>
        <triggerType>onAllChanges</triggerType>
    </rules>
    <rules>
        <fullName>Review is Incomplete</fullName>
        <actions>
            <name>Uncheck_Review_Completed</name>
            <type>FieldUpdate</type>
        </actions>
        <active>true</active>
        <formula>OR(ISNULL(Cultural_Fit__c), ISNULL(Experience__c), ISNULL(Leadership_Skills__c))</formula>
        <triggerType>onAllChanges</triggerType>
    </rules>
</Workflow>
