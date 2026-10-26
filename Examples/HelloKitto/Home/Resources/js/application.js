/*-------------------------------------------------------------------------------
   Copyright 2012-2026 Ethea S.r.l.

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
-------------------------------------------------------------------------------*/

// Counts the occurrences of fieldName = value
// in the specified recordset. Useful to be called
// in a group template.
function countValues(recordSet, fieldName, value) {
  result = 0;
  for (i = 0; i < recordSet.length; i++)
    if (recordSet[i].data[fieldName] == value)
      result++;
  return result;
};

function getAgeClass(age) {
  if (age >= 15) {
    return 'important-row';
  } else if (age >= 12) {
    return 'semi-important-row';
  } else {
    return '';
  }
};
