# SQLServer
**SQLServer Enterprise Edition features detection: **

SQL Server Enterprise Edition provides datacenter capabilities with high performance, unlimited virtualization and many business intelligence tools. Sometimes it is not easy to identify if you are using any Enterprise Edition features or not.

This script will help you identify if you are using any Enterprise edition featuers or not, it cover majority of use case, it does not check each and every feature, but covers the most commonly used features. 

**This script requires you to provide login with dbreader/select on master and ALTER ANY EVENT SESSION. It will retun 1 if any of the bellow Enterprise Edition features are being used. **
It checks following features:
1. Database level features 
2. Online Index Rebuild used outside DB Maintenance plan 
3. Read replicas of Availablity group
4. Asynchronous Replica of Availablity group 
5. Resource Governor 
6. R extention
7. Python extention
8. Memory Optimized tempdb metadata
9. more than 128G of memory 
10. more than 48 VCPU of CPU
11. Asynchronous mirroring

**Note:  In order to find Online index rebuild feature, you have to run the script during maintenance window during weekend or for minimum of a week on 5 min schedule basis so that you can capture all the occurance of it. This script is very light weight. 

Please note that it is the customers responsibility to make sure you are not using any enterprise features or not.
