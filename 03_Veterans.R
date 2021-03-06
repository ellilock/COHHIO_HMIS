# COHHIO_HMIS
# Copyright (C) 2020  Coalition on Homelessness and Housing in Ohio (COHHIO)
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Affero General Public License for more details at
# <https://www.gnu.org/licenses/>.

library(tidyverse)
library(lubridate)

load("images/COHHIOHMIS.RData")
load("images/cohorts.RData")

rm(Affiliation, Disabilities, EmploymentEducation, EnrollmentCoC, Exit,
   Export, Funder, HealthAndDV, IncomeBenefits, Offers, Organization, 
   ProjectCoC, Scores, Services, Users, stray_services)

# getting all the veterans
Veterans <- Client %>%
  filter(VeteranStatus == 1) %>%
  select(PersonalID, AmIndAKNative, Asian, BlackAfAmerican, NativeHIOtherPacific,
         White, RaceNone, Ethnicity, Gender)

# getting all the EE data of all the veterans
VeteranHHs <- Veterans %>%
  left_join(Enrollment, by = "PersonalID") %>%
  select(PersonalID, ProjectID, EnrollmentID, EntryDate, HouseholdID, 
         RelationshipToHoH, LivingSituation, LengthOfStay, LOSUnderThreshold,
         PreviousStreetESSH, DateToStreetESSH, TimesHomelessPastThreeYears,
         MonthsHomelessPastThreeYears, DisablingCondition, DateOfEngagement,
         MoveInDate, VAMCStation, CountyServed, CountyPrior, ExitDate, 
         Destination, OtherDestination, ExitAdjust, AgeAtEntry)

# adding in all the provider data 
VeteranHHs <- Project %>%
  select(ProjectID, OrganizationName, OperatingStartDate, OperatingEndDate,
         ProjectType, GrantType, ProjectName, ProjectAKA, ProjectRegion) %>%
  right_join(VeteranHHs, by = "ProjectID")

VeteranHHs <- VeteranHHs %>%
  left_join(VeteranCE, by = c("PersonalID", "EnrollmentID"))

CurrentVeterans <- VeteranHHs %>%
  filter((ProjectType %in% c(1, 2, 4, 8, 12) & (
    ymd(EntryDate) <= today() &
      (is.na(ExitDate) | ymd(ExitDate) > today())
  )) |
    (ProjectType %in% c(3, 9, 13) & (
      ymd(MoveInDate) <= today() &
        (is.na(ExitDate) |
           ymd(ExitDate) > today())
    )))

CurrentVeteranCounts <- CurrentVeterans %>%
  filter(ProjectType %in% c(1, 2, 4, 8)) %>%
  mutate(ProjectRegion = if_else(is.na(ProjectRegion),
                                 "Balance of State",
                                 ProjectRegion)) %>%
  group_by(ProjectName, ProjectRegion) %>%
  summarise(Veterans = n()) %>%
  ungroup()

VeteranEngagement <- CurrentVeterans %>%
  filter(ProjectType %in% c(1, 2, 4, 8)) %>%
  mutate(
    EngagementStatus = case_when(
      !is.na(PHTrack) & PHTrack != "None" &
        ymd(ExpectedPHDate) >= today() ~ "Has Current Housing Plan",
      is.na(PHTrack) | PHTrack == "None" |
        (!is.na(PHTrack) & (
          ymd(ExpectedPHDate) < today() |
            is.na(ExpectedPHDate)
        )) ~ "No Current Housing Plan"
    ),
    ProjectRegion = if_else(is.na(ProjectRegion),
                            "Balance of State",
                            ProjectRegion)
  ) %>% 
  select(ProjectName, ProjectType, ProjectRegion, PersonalID, PHTrack, 
         ExpectedPHDate, EngagementStatus)

veteran_current_in_project <- VeteranEngagement %>%
  group_by(ProjectName, ProjectType, ProjectRegion, EngagementStatus) %>%
  summarise(CurrentVeteranCount = n()) %>%
  spread(key = EngagementStatus, value = CurrentVeteranCount) %>%
  rename(HasCurrentHousingPlan = `Has Current Housing Plan`,
         NoCurrentHousingPlan = `No Current Housing Plan`) 

veteran_current_in_project[is.na(veteran_current_in_project)] <- 0 

veteran_current_in_project <- veteran_current_in_project %>%
  mutate(
    Summary =
      case_when(
        HasCurrentHousingPlan == 0 &
          NoCurrentHousingPlan == 1 ~
          "This veteran has no current Housing Plan",
        HasCurrentHousingPlan == 0 &
          NoCurrentHousingPlan > 1  ~
          "None of these veterans have current Housing Plans",
        HasCurrentHousingPlan == 1 &
          NoCurrentHousingPlan == 0 ~
          "This veteran has a current Housing Plan!",
        HasCurrentHousingPlan > 1 &
          NoCurrentHousingPlan == 0  ~
          "All veterans in this project have current Housing Plans!",
        HasCurrentHousingPlan == 1 &
          NoCurrentHousingPlan > 0 ~
          paste(HasCurrentHousingPlan, 
                "of these veterans has a current Housing Plan"),
        HasCurrentHousingPlan > 1 &
          NoCurrentHousingPlan > 0 ~
          paste(HasCurrentHousingPlan, 
                "of these veterans have current Housing Plans")
      )
  ) %>%
  left_join(CurrentVeteranCounts, by = c("ProjectName", "ProjectRegion")) %>%
  ungroup()

current_tay_hohs <- tay %>%
  filter(RelationshipToHoH == 1 & 
           is.na(ExitDate) & 
           ProjectType %in% c(1, 2, 4, 8)) %>%
  select(PersonalID,
         EnrollmentID,
         ProjectName,
         ProjectType) %>%
  left_join(
    VeteranCE %>%
      select(PersonalID,
             EnrollmentID,
             PHTrack,
             ExpectedPHDate),
    by = c("PersonalID", "EnrollmentID")
  ) %>%
  mutate(EngagementStatus = case_when(
    !is.na(PHTrack) & PHTrack != "None" &
      ymd(ExpectedPHDate) >= today() ~ "Has Current Housing Plan",
    is.na(PHTrack) | PHTrack == "None" |
      (!is.na(PHTrack) & (
        ymd(ExpectedPHDate) < today() |
          is.na(ExpectedPHDate)
      )) ~ "No Current Housing Plan"
  )) %>%
  group_by(ProjectName, ProjectType, EngagementStatus) %>%
  summarise(CurrentTAYCount = n()) %>%
  spread(key = EngagementStatus, value = CurrentTAYCount) %>%
  rename(HasCurrentHousingPlan = `Has Current Housing Plan`,
         NoCurrentHousingPlan = `No Current Housing Plan`) %>%
  ungroup()

current_tay_hohs[is.na(current_tay_hohs)] <- 0

CurrentTAYHHs <- tay %>%
  filter(is.na(ExitDate) & 
           ProjectType %in% c(1, 2, 4, 8) & 
           RelationshipToHoH == 1) %>%
  group_by(ProjectName) %>%
  summarise(TAYHHs = n()) %>%
  ungroup()

current_tay_hohs <- current_tay_hohs %>%
  left_join(CurrentTAYHHs, by = "ProjectName") %>%
  mutate(
    Summary =
      case_when(
        HasCurrentHousingPlan == 0 &
          NoCurrentHousingPlan == 1 ~
          "This Transition Aged Youth household has no current Housing Plan",
        HasCurrentHousingPlan == 0 &
          NoCurrentHousingPlan > 1  ~
          "None of these Transition Aged Youth households have current Housing Plans",
        HasCurrentHousingPlan == 1 &
          NoCurrentHousingPlan == 0 ~
          "This Transition Aged Youth household has a current Housing Plan!",
        HasCurrentHousingPlan > 1 &
          NoCurrentHousingPlan == 0  ~
          "All Transition Aged Youth households in this project have current Housing Plans!",
        HasCurrentHousingPlan == 1 &
          NoCurrentHousingPlan > 0 ~
          paste(
            HasCurrentHousingPlan,
            "of these Transition Aged Youth households has a current Housing Plan"
          ),
        HasCurrentHousingPlan > 1 &
          NoCurrentHousingPlan > 0 ~
          paste(
            HasCurrentHousingPlan,
            "of these Transition Aged Youth households have current Housing Plans"
          )
      )
  )

rm(Client, CaseManagers, Enrollment, Inventory, Project, regions, VeteranCE, 
   Veterans, CurrentVeterans, VeteranEngagement, VeteranHHs, 
   Referrals, CurrentVeteranCounts, CurrentTAYHHs, Contacts, covid19, HUD_specs)

rm(list = ls(pattern = "co_"))

save.image("images/Veterans.RData")


