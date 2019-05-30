The SQL files here are based on an Multi Level Business structure as follows:
Notation: ">" = "Manager Of"

A > B, C
B > D
D > E
C > F

Then A is the root node in a hierarchical diagram with Generation = 1 while B, C are in Generation 2;
D and F in Generation 3, E in Generation 3.
There might be several root nodes i.e. toplines. In this example, the topline for all nodes is A 

## PRECEDURES
### Topline Calculator: 
Calculates the topline of the branch that the node is in.
While this could also be done by CONNECT BY statement in ORACLE, this procedure works faster

### Generation Computer: 
Calcuates the Generation within the branch where topline gets the Generation = 1

### Drop If Exists: 
Unlike MySQL, ORACLE does not have DROP IF EXISTS statement. This procedure provides with that functionality

### Truncate If Exists:
Similar to the Drop If Exists

### IS Inactives & Inside Sales Newcomers(Welcome): 
Other

## FUNCTIONS:
### Get Campaign ID & Get Campaign: 
These two enable going forward / behind X reporting periods. IS_Campaigns table holds the info on
reporting period and the associated period ID. Using these two in combination, one match info from any 2 reporting periods

### Generation Count: 
Function to count the number of people in a particular generation. This function is used as the stopping
condition of the loop in Topline Calculator procedure's

## QUERIES
### Hierarchical Sales Calculation:
This gives the generation of one person with respect to the highest level within the sales 'leg'