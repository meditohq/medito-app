/*This file is part of Medito App.

Medito App is free software: you can redistribute it and/or modify
it under the terms of the Affero GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Medito App is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
Affero GNU General Public License for more details.

You should have received a copy of the Affero GNU General Public License
along with Medito App. If not, see <https://www.gnu.org/licenses/>.*/

class ListItem {
  String thumbnail;
  String title;
  String id;
  String description = '';
  String contentText;
  ListItemType type;
  FileType fileType;
  String url;
  String parentId;

  ListItem(this.title, this.id, this.type,
      {this.description,
        this.fileType,
        this.url,
        this.parentId,
        this.thumbnail,
        this.contentText});
}

enum ListItemType { folder, file, illustration }
enum FileType { audio, text, both, audiosetdaily, audiosethourly }
