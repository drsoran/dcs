local updateInterval = 0.1;

--------------
-- Score
--------------

Score = {
  timeInFormation = 0
}

function Score:New()
  local o = {
    timeInFormation = 0
  };

  setmetatable(o, {__index = self});
  return o;
end

function Score:AddSecondsInFormation(seconds)
  self.timeInFormation = self.timeInFormation + seconds;
end

function Score:GetSecondsInFormation()
  return math.floor(self.timeInFormation);
end

function Score:Reset()
  self.timeInFormation = 0;
end

----------------
-- Formation
----------------

Formation = {
  name = "",
  description = "",
  angles = {},
  baseDistanceFT = {}
}

function Formation:New(name, description, angles, baseDistanceFT)
  local o = {
    name = name,
    description = description,
    angles = angles,
    baseDistanceFT = baseDistanceFT;
  };

  setmetatable(o, {__index = self});
  return o;
end

function Formation:ToSting()
  return string.format("%s: %s", self.name,  self.description);
end

----------------
-- Student
----------------

Student = {
  score = nil,
  number = 0,
  client = nil,
  angleToInstructor = 0,
  distanceToInstructorFT = 0,
  formation = nil
}

function Student:New(client, number)
  local o = {
    score = Score:New(),
    number = number,
    client = client,
    angleToInstructor = 0,
    distanceToInstructor = 0,
    formation = nil
  };

  setmetatable(o, {__index = self});
  return o;
end

function Student:IsAlive()
  return self.client:IsAlive();
end

function Student:GetScore()
  return self.score;
end

function Student:Update(instructor)
  self:calculateAngleAndDist(instructor);
end

function Student:SetFormation(formation)
  self.formation = formation;
end

function Student:GetReportLine()
  local inZoneMarker = "   ";

  if (self.formation) then
    if (self:isInFormation()) then
      self.score:AddSecondsInFormation(updateInterval);
      if (self.score:GetSecondsInFormation() % 2 == 0) then
        inZoneMarker = ">> ";
      end
    end
  end

  local function formatDistance()
    if (self.distanceToInstructorFT < 6076) then -- 1 NM in ft
      return string.format('%d FT', self.distanceToInstructorFT);
    else
      return string.format('%.2f NM', UTILS.Round(self.distanceToInstructorFT / 6076.12, 2));
    end
  end

  local angleDistFmt = string.format('%03d°, %s', self.angleToInstructor, formatDistance());

  return string.format("%s#%d %s: %s, T: %s",
    inZoneMarker,
      self.number,
      self.client:GetPlayer(),
      angleDistFmt,
      UTILS.SecondsToClock(self.score:GetSecondsInFormation(), true));

end

function Student:toAngleLR(heading, fromCoordinate, toCoordinate)
  local dir = fromCoordinate:GetDirectionVec3(toCoordinate);
  local angle = fromCoordinate:GetAngleDegrees(dir);
  local aspect = angle - heading;

  if aspect > 180 then
    aspect = aspect - 360;
  end

  if (aspect >= 0 and aspect <= 180) then
    return 90 - aspect;
  end

  if (aspect < 0 and aspect >= -180) then
    return 90 + aspect;
  end

  return aspect;
end

function Student:calculateAngleAndDist(instructor)
  local pFrom = self.client:GetCoordinate();
  local pTo = instructor:GetCoordinate();
  self.distanceToInstructorFT = math.floor(UTILS.MetersToFeet(pFrom:Get2DDistance(pTo)));
  self.distanceToInstructorFT = self.distanceToInstructorFT - 33; -- substract 2 times wingspan half of the Viper (2 * 16ft)
  self.angleToInstructor = math.floor(self:toAngleLR(instructor:GetHeading(), pFrom, pTo));
end

function Student:isInFormation()
  local inSpot
    = self.angleToInstructor >= self.formation.angles[1]
      and self.angleToInstructor <= self.formation.angles[2]
      and self.distanceToInstructorFT >= self.formation.distanceToInstructorFT[1]
      and self.distanceToInstructorFT <= self.formation.distanceToInstructorFT[2];

  return inSpot;
end

----------------
-- Entry
----------------

local formations = {
  Formation:New("Fingertip", "45° - 75ft separation", {40, 50}, {70, 80}),
  Formation:New("Route", "45° - 500ft separation", {40, 50}, {520, 620})
}

function FormationInstructor(groupName, instructorName, stud1, stud2, stud3, stud4)
  local instructor_group = GROUP:FindByName(groupName);
  local instructor_unit = UNIT:FindByName(instructorName);

  local student_1_client = CLIENT:FindByName(stud1);
  local student_2_client = CLIENT:FindByName(stud2);
  local student_3_client = CLIENT:FindByName(stud3);
  local student_4_client = CLIENT:FindByName(stud4);

  local updateTimer = nil;

  local students = {
    Student:New(student_1_client, 1),
    Student:New(student_2_client, 2),
    Student:New(student_3_client, 3),
    Student:New(student_4_client, 4),
  };

  local function updateStudents()
    local anyAlive = false;
    local report = REPORT:New();

    report:Add(formations[1]:ToSting());

    for i = 1, #students do
      local student = students[i];

      if (student:IsAlive()) then
        anyAlive = true;
        student:Update(instructor_unit);
        report:Add("-----");
        report:Add(student:GetReportLine());
      else
        student:GetScore():Reset();
      end
    end

    if (not anyAlive) then
      if (updateTimer) then
        updateTimer:Stop();
        updateTimer = nil;
      end

      return;
    end

    MESSAGE:New(report:Text(), 1, nil, true):ToBlue();
  end

  local function onStudentJoined(student)
    -- MESSAGE:New("Joined", 1):ToBlue();

    student:SetFormation(formations[1]);

    if (not instructor_group:IsActive()) then
      instructor_group:Activate();
    end

    if (not updateTimer) then
      -- MESSAGE:New("Start timer", 1):ToBlue();
      updateTimer = TIMER:New(updateStudents):Start(1, updateInterval, nil);
    end
  end

  student_1_client:Alive(function () onStudentJoined(students[1]) end);
  student_2_client:Alive(function () onStudentJoined(students[2]) end);
  student_3_client:Alive(function () onStudentJoined(students[3]) end);
  student_4_client:Alive(function () onStudentJoined(students[4]) end);
end
